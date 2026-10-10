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
      '用户明确要求新建任务时，taskId 必须省略或传 JSON null，不能传空字符串或旧任务标识。创建失败不能改用旧任务冒充新任务。'
      '任务只是当前 AI 工作内容的组织方式，共用身份和长期记忆，引用私聊上下文，不分叉或复制历史。'
      '任务有独立的消息页面和执行会话。可以在当前私聊准备内容，再用 runTask(startExecution:false) 创建任务，使用返回的 conversationId 将内容或小程序发到任务里。'
      '任务就绪后系统会自动在当前私聊发送任务卡片，并更新这条卡片的执行状态；不要再手动发送重复的任务入口。'
      '可选提供 description，不超过100字，作为任务内的系统说明，简短说明这次工作缘由或安排；系统自动附上查看来源，不要在说明里写链接或把未完成的事说成已完成。'
      '需要任务立即继续工作时，runTask 默认 startExecution:true，将 task 作为你自己的执行安排传入，不冒充用户发言。'
      '创建任务不等于开启目标模式；不要仅因用户说“开个任务”就调用 createGoal，更不要自行设置 Token 预算。'
      '简单问答直接回复，不必建任务。任务通过异步工具执行，你可以继续处理用户的新消息；'
      '用户要求在任务里玩棋类等回合制小程序时，可先在私聊找好已有小程序，创建任务但不启动额外模型执行，再用 sendHtmlMessage(conversationId:任务会话) 发棋盘并按协议开局。'
      '所有开局和落子使用任务内的同一条棋盘消息；轮到用户时等待落子回调，不轮询等待、不为每步新建任务。'
      '结果会更新原工具记录并交回给你，由你核实完成情况后在当前私聊回复。'
      '不得把 pending 当作完成，也不得为同一件事重复启动任务。';

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'runTask',
    capabilityId: 'runtime.subagent',
    safety: ToolSafety.lowRisk,
    executionTimeout: Duration(seconds: 30),
    description:
        'Organize authorized work in a separate task conversation linked to this personal chat, using the same AI identity and memory with references to the source chat. '
        'You may prepare content/apps in the parent chat, create a task with startExecution:false, then send the prepared content with conversationId from this result. This creates the destination without starting a second model execution or inserting a fake user request. '
        'With startExecution:true (default), task is your own execution brief and starts/resumes work inside the task conversation; it is not a new statement by the human. '
        'A task does not imply goal mode or a token budget. Do not ask the task to createGoal unless explicitly requested, and never invent a token budget. '
        'Returns pending only when execution starts. With startExecution:false it returns the ready task destination immediately. Running results update the same tool record asynchronously. '
        'Continue responding to independent user messages; verify the result and report in this chat. '
        'A task persists across executions and follow-ups. Supply the existing taskId to continue or steer it, including while it is running. '
        'Only omit taskId for a new independent objective. Find existing tasks with searchConversations. '
        'Use for concrete work worth tracking, not ordinary chat. At most 3 concurrent tasks; updates to existing tasks are delivered immediately.',
    inputSchema: {
      'type': 'object',
      'additionalProperties': false,
      'properties': {
        'taskId': {
          'type': ['string', 'null'],
          'minLength': 1,
          'description':
              'Existing task ID only when continuing that task. For a NEW task omit this field or pass JSON null; never use an empty string or an old task ID. Never ask the user for an ID.',
        },
        'title': {'type': 'string', 'minLength': 1, 'maxLength': 60},
        'description': {
          'type': 'string',
          'minLength': 1,
          'maxLength': 100,
          'description':
              'Optional user-visible explanation of this task arrangement, at most 100 characters, shown as a system notice. Describe the actual intent without claiming unfinished work is complete. The app appends a source link automatically.',
        },
        'startExecution': {
          'type': 'boolean',
          'default': true,
          'description':
              'false creates/reopens the task destination only; send prepared content or a game there using the returned conversationId. true starts/resumes a model execution and requires task.',
        },
        'task': {
          'type': 'string',
          'minLength': 1,
          'maxLength': 16000,
          'description':
              'Your own execution brief within the user-authorized scope. Required only when startExecution is true. Do not impersonate the user or copy chat history.',
        },
      },
      'required': ['title'],
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
    final description = call.arguments['description'] as String?;
    if (description != null &&
        (description.trim().isEmpty || description.runes.length > 100)) {
      throw ArgumentError('任务说明填写时须为1至100字');
    }
    final startExecution = call.arguments['startExecution'] as bool? ?? true;
    if (startExecution &&
        (call.arguments['task'] is! String ||
            (call.arguments['task'] as String).trim().isEmpty)) {
      throw ArgumentError('启动任务执行需要 task；只创建任务入口请设置 startExecution:false');
    }
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
    if (!startExecution) {
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.success,
        output: {
          ...execution.initialOutput,
          'pending': false,
          'executionStarted': false,
          'message': '任务已就绪，未启动额外执行。可将准备好的内容或小程序发送到返回的 conversationId。',
        },
      );
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
        'executionStarted': true,
        'message':
            '任务正在执行你提交的工作安排；不要在私聊重复执行相同工作。'
            '补充要求沿用此 taskId，结果将更新这次工具调用；pending 不代表已完成。',
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
