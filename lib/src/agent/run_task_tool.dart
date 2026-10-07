import 'dart:async';
import '../domain/error_message.dart';
import '../domain/tool_models.dart';
import 'agent_runtime.dart';
import 'deferred_tool.dart';

class RunTaskTool implements DeferredAgentTool, RuntimeCapabilityAgentTool {
  RunTaskTool(this.prepare, {required this.onError});
  final Future<DeferredToolExecution> Function(ToolCall, bool Function())
  prepare;
  final void Function(Object) onError;
  final _pending = <String, DeferredToolExecution>{};
  final _updates = <ToolResult>[];
  Completer<void> _changed = Completer<void>();
  (Object, StackTrace)? _failure;
  bool _cancelled = false;
  int _preparing = 0;

  static const instructions =
      '用户交代需要持续执行或单独查看的工作时，可用 runTask 组织为任务。'
      '一项任务具有固定 taskId，可以持续执行、接受补充并多次推进。'
      '继续同一件事必须传原 taskId，不得为每次回复或执行新建任务；只有独立的新工作才省略 taskId。'
      '任务只是当前 AI 工作内容的组织方式，共用身份和长期记忆，引用私聊上下文，不分叉或复制历史。'
      '简单问答直接回复，不必建任务。任务通过异步工具执行，你可以继续处理用户的新消息；'
      '结果会更新原工具记录并交回给你，由你核实完成情况后在当前私聊回复。'
      '不得把 pending 当作完成，也不得为同一件事重复启动任务。';

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'runTask',
    capabilityId: 'runtime.subagent',
    safety: ToolSafety.lowRisk,
    executionTimeout: Duration(seconds: 30),
    description:
        'Organize authorized work as a task of this same AI in the current conversation. '
        'Inherits current conversation history, memory and user constraints; no new conversation or context fork. '
        'Returns pending after setup. Its result updates the same tool record asynchronously. '
        'Continue responding to independent user messages; verify the result and report in this chat. '
        'A task persists across executions and follow-ups. Supply the existing taskId to continue or steer it, including while it is running. '
        'Only omit taskId for a new independent objective. Find existing tasks with searchConversations. '
        'Use for concrete work worth tracking, not ordinary chat. At most 3 concurrent tasks; updates to existing tasks are delivered immediately.',
    inputSchema: {
      'type': 'object',
      'additionalProperties': false,
      'properties': {
        'taskId': {
          'type': 'string',
          'description':
              'Existing task ID returned by runTask or searchConversations. Omit only when starting independent work. Never ask the user for an ID.',
        },
        'title': {'type': 'string', 'minLength': 1, 'maxLength': 60},
        'task': {
          'type': 'string',
          'minLength': 1,
          'maxLength': 16000,
          'description':
              'Concrete objective, completion criteria and authorized scope. Do not copy chat history.',
        },
      },
      'required': ['title', 'task'],
    },
  );

  @override
  bool get hasPending => _pending.isNotEmpty;
  @override
  bool get hasUpdates => _updates.isNotEmpty || _failure != null;
  @override
  List<ToolResult> takeUpdates() {
    if (_failure case final failure?) {
      _failure = null;
      Error.throwWithStackTrace(failure.$1, failure.$2);
    }
    final updates = List<ToolResult>.of(_updates);
    _updates.clear();
    return updates;
  }

  @override
  Future<void> waitForPending() =>
      hasUpdates || !hasPending ? Future.value() : _changed.future;

  void _signal() {
    _changed.complete();
    _changed = Completer<void>();
  }

  @override
  Future<ToolResult> execute(ToolCall call) async {
    if (_cancelled) throw const AgentCancelled();
    final taskId = call.arguments['taskId'];
    final activeTasks = _pending.values
        .map((execution) => execution.initialOutput['taskId'])
        .toSet();
    final opensSlot = taskId == null || !activeTasks.contains(taskId);
    if (opensSlot && activeTasks.length + _preparing >= 3) {
      throw StateError('已有 3 项任务在执行，请等待结果；现有任务仍可补充要求。');
    }
    if (opensSlot) _preparing++;
    late final DeferredToolExecution execution;
    try {
      execution = await prepare(call, () => _cancelled);
    } finally {
      if (opensSlot) _preparing--;
    }
    _pending[call.id] = execution;
    unawaited(
      execution
          .finish()
          .then(
            (result) => result,
            onError: (Object error, StackTrace stack) {
              final stopped = _cancelled || error is AgentCancelled;
              if (!stopped) onError(error);
              return ToolResult(
                callId: call.id,
                toolName: call.name,
                status: stopped
                    ? ToolResultStatus.cancelled
                    : ToolResultStatus.error,
                output: {
                  ...execution.initialOutput,
                  'pending': false,
                  if (!stopped) 'error': errorMessage(error),
                  if (stopped) 'cancelled': true,
                },
              );
            },
          )
          .then<void>(
            (result) {
              _pending.remove(call.id);
              _updates.add(result);
              _signal();
            },
            onError: (Object error, StackTrace stack) {
              _failure = (error, stack);
              _pending.remove(call.id);
              _signal();
            },
          ),
    );
    return ToolResult(
      callId: call.id,
      toolName: call.name,
      status: ToolResultStatus.success,
      output: {
        ...execution.initialOutput,
        'pending': true,
        'message': '任务正在持续执行。补充要求沿用此 taskId，结果将更新这次工具调用。',
      },
    );
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
    await Future.wait([
      for (final execution in _pending.values.toList()) execution.cancel(),
    ]);
    _signal();
  }
}
