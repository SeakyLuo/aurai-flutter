import 'private_task_tool.dart';
import 'dart:async';
import 'dart:convert';

import '../domain/agent_models.dart';
import '../domain/context_summary.dart';
import '../domain/model_provider.dart';
import '../domain/tool_models.dart';
import 'tool_executor.dart';
import 'ask_user_tool.dart';
import 'tool_registry.dart';

class AgentCancelled implements Exception {
  const AgentCancelled();
}

class AgentRuntime {
  AgentRuntime({
    required ModelProvider provider,
    required ToolRegistry registry,
    required ToolExecutor executor,
  }) : _provider = provider,
       _registry = registry,
       _executor = executor;

  final ModelProvider _provider;
  final ToolRegistry _registry;
  final ToolExecutor _executor;
  String? get activeToolName => _executor.activeToolName;
  bool _cancelRequested = false;

  Future<AgentRunResult> run({
    required List<AgentMessage> conversation,
    required AgentStepListener onStepsChanged,
    ContextSummary? contextSummary,
    ContextSummary? privateContextSummary,
    FutureOr<String> Function()? personalContext,
    Future<void> Function(ContextSummary)? onContextSummary,
    Future<void> Function(ContextSummary)? onPrivateContextSummary,
    void Function(bool)? onCompactionChanged,
    FutureOr<void> Function()? onTurnStarted,
    Future<void> Function(ModelTurn)? onTurnCompleted,
    Future<void> Function(ToolCall)? onToolStarted,
    Future<void> Function(ToolResult)? onToolCompleted,
    bool Function(ToolResult)? endsRun,
    void Function(String text)? onTextChanged,
    void Function(String text)? onReasoningChanged,
    void Function()? onProcessingStarted,
    void Function(int attempt)? onReconnect,
    void Function(int index)? onMessageStarted,
  }) async {
    _cancelRequested = false;
    final steps = <AgentStep>[];
    final stepIndices = <String, int>{};
    String? continuationToken;
    var invalidArgumentTurns = 0;
    var toolResults = const <ToolResult>[];

    final questions = _registry.find('askUser') as AskUserTool?;
    final task = (_registry.find('getGoal') as PrivateTaskTool?)?.store;
    var goalContinuation = false;
    try {
      while (true) {
        _throwIfCancelled();
        final updates = questions?.takeUpdates() ?? const <ToolResult>[];
        for (final update in updates) {
          await onToolCompleted?.call(update);
          final index = stepIndices[update.callId]!;
          steps[index] = steps[index].copyWith(
            status: update.status == ToolResultStatus.cancelled
                ? AgentStepStatus.cancelled
                : AgentStepStatus.completed,
            detail: _stepDetail(update),
            resultJson: jsonEncode(update.output),
          );
        }
        if (updates.isNotEmpty) onStepsChanged(List.unmodifiable(steps));
        var goalActiveAtTurnStart = false;
        if (task != null) {
          final state = await task.read();
          if (state['status'] == 'active') {
            final problem = await task.budgetProblem();
            if (problem != null) {
              return AgentRunResult(
                answer: '',
                steps: List.unmodifiable(steps),
              );
            }
            goalActiveAtTurnStart = true;
            await task.beginTurn();
          }
        }
        await onTurnStarted?.call();
        final modelTurn = await _provider.respond(
          ModelRequest(
            messages: conversation,
            contextSummary: contextSummary,
            privateContextSummary: privateContextSummary,
            personalContext: [
              await personalContext?.call() ?? '',
              if (task != null) await task.context(),
            ].join('\n\n'),
            onContextSummary: onContextSummary,
            onPrivateContextSummary: onPrivateContextSummary,
            onCompactionChanged: onCompactionChanged,
            onMessageStarted: onMessageStarted,
            onReconnect: onReconnect,
            onProcessingStarted: () {
              _throwIfCancelled();
              onProcessingStarted?.call();
            },
            onReasoningChanged: (text) {
              _throwIfCancelled();
              onReasoningChanged?.call(text);
            },
            onTextChanged: (text) {
              _throwIfCancelled();
              onTextChanged?.call(text);
            },
            tools: _registry.beginTurn(),
            capabilities: _registry.capabilities,
            continuationToken: continuationToken,
            toolResults: toolResults,
            userUpdates: [
              if (goalContinuation)
                '运行时续跑提醒（不是新的用户授权）：目标仍未完成。继续推进并验证完成条件；完成后调用 updateGoal。相同阻塞条件连续三轮仍无法推进才会停止；有进展时用 active 清除阻塞计数，需要用户信息用 askUser。不要只重复进度说明。',
              for (final update in updates)
                'Response to the earlier askUser question: ${jsonEncode(update.output)}',
            ],
          ),
        );
        goalContinuation = false;
        continuationToken = modelTurn.continuationToken;
        _throwIfCancelled();

        if (modelTurn.text != null && modelTurn.text!.isNotEmpty) {
          onTextChanged?.call(modelTurn.text!);
        }

        if (task != null && (await task.read())['runningSince'] != null) {
          await task.change((_) {});
        }
        await onTurnCompleted?.call(modelTurn);
        if (goalActiveAtTurnStart) {
          await task!.recordUsage(modelTurn.response['usage'] as Map?);
          final problem = await task.budgetProblem();
          if (problem != null) {
            for (final call in modelTurn.toolCalls) {
              final tool = _registry.find(call.name);
              final arguments =
                  call.argumentsError == null && tool is ToolHistoryAgentTool
                  ? (tool as ToolHistoryAgentTool).historyArguments(call)
                  : call.arguments;
              await onToolStarted?.call(
                ToolCall(id: call.id, name: call.name, arguments: arguments),
              );
              await onToolCompleted?.call(
                ToolResult(
                  callId: call.id,
                  toolName: call.name,
                  status: ToolResultStatus.cancelled,
                  output: {'performed': false, 'reason': problem},
                ),
              );
            }
            return AgentRunResult(
              answer: modelTurn.text?.trim() ?? '',
              steps: List.unmodifiable(steps),
            );
          }
        }
        if (modelTurn.response['status'] == 'failed') {
          throw ModelProviderException(
            '模型回复失败，已保留生成的内容，请重试',
            detail: jsonEncode(modelTurn.response['error']),
          );
        }
        if (modelTurn.response['status'] == 'incomplete') {
          final reason =
              (modelTurn.response['incomplete_details'] as Map?)?['reason'];
          final hasText = modelTurn.text?.isNotEmpty == true;
          final hasToolOutput = (modelTurn.response['output'] as List)
              .cast<Map>()
              .any((item) => item['type'] == 'function_call');
          throw ModelProviderException(switch (reason) {
            'max_output_tokens' || 'length' =>
              hasToolOutput
                  ? '生成工具参数时达到输出上限，本轮工具尚未执行，请继续或重试'
                  : hasText
                  ? '回复达到输出上限，已保留已生成的正文，请继续或重试'
                  : '模型生成时达到输出上限，尚未生成回复，请重试',
            'content_filter' =>
              hasText ? '回复因内容限制未完成，已保留已生成的正文' : '回复因内容限制未完成，尚未生成正文',
            _ => hasText ? '回复未完成，已保留已生成的正文，请重试' : '回复未完成，尚未生成正文，请重试',
          }, detail: jsonEncode(modelTurn.response['incomplete_details']));
        }
        if (modelTurn.toolCalls.isEmpty) {
          final messages = (modelTurn.response['output'] as List? ?? const [])
              .cast<Map>()
              .where((item) => item['type'] == 'message');
          final activeGoal =
              task != null && (await task.read())['status'] == 'active';
          if (!activeGoal &&
              messages.isNotEmpty &&
              messages.last['phase'] == 'commentary') {
            throw const ModelProviderException('模型只返回了过程说明，尚未给出最终答复，请继续或重试');
          }
          if (questions != null &&
              (questions.hasPending || questions.hasUpdates)) {
            await task?.stopClock();
            await questions.waitForPending();
            _throwIfCancelled();
            toolResults = const [];
            continue;
          }
          if (activeGoal) {
            goalContinuation = true;
            toolResults = const [];
            continue;
          }
          return AgentRunResult(
            answer: modelTurn.text?.trim() ?? '',
            steps: List.unmodifiable(steps),
          );
        }

        if (modelTurn.toolCalls.any((call) => call.argumentsError != null)) {
          invalidArgumentTurns++;
          if (invalidArgumentTurns > 2) {
            throw const ModelProviderException(
              '模型连续生成了无效工具参数，修正两次后仍失败，本轮工具未执行，请重试',
            );
          }
        } else {
          invalidArgumentTurns = 0;
        }

        final nextResults = <ToolResult>[];
        var userHandoffOccurred = false;
        for (final call in modelTurn.toolCalls) {
          _throwIfCancelled();
          onProcessingStarted?.call();
          final tool = _registry.find(call.name);
          final toolArguments =
              call.argumentsError == null && tool is ToolHistoryAgentTool
              ? (tool as ToolHistoryAgentTool).historyArguments(call)
              : call.arguments;
          final historyArguments = {
            ...toolArguments,
            if (call.userAction != null) 'userAction': call.userAction,
          };
          await onToolStarted?.call(
            ToolCall(id: call.id, name: call.name, arguments: historyArguments),
          );
          stepIndices[call.id] = steps.length;
          steps.add(
            AgentStep(
              toolName: call.name,
              title: toolTitle(call.name),
              status: AgentStepStatus.running,
              requestJson: jsonEncode(historyArguments),
            ),
          );
          onStepsChanged(List.unmodifiable(steps));
          final result = userHandoffOccurred
              ? ToolResult(
                  callId: call.id,
                  toolName: call.name,
                  status: ToolResultStatus.cancelled,
                  output: const {
                    'cancelled': true,
                    'performed': false,
                    'reason': '前一步已交给用户操作，此次预排动作未执行。请先根据用户反馈核实状态，再决定后续操作。',
                  },
                )
              : call.argumentsError != null
              ? ToolResult(
                  callId: call.id,
                  toolName: call.name,
                  status: ToolResultStatus.error,
                  output: {
                    'performed': false,
                    'error': 'invalid_tool_arguments',
                    'detail': call.argumentsError,
                    'instruction':
                        r'该工具未执行。请根据 detail 中的位置和原始 JSON 片段修正语法，特别检查对象/数组的闭合括号和逗号。不要原样重发错误参数。请重新生成符合工具 schema 的完整 JSON 对象；字符串中的换行必须写为 \n，制表符写为 \t，双引号和反斜杠必须正确转义。不要重发已经成功执行的其他工具。',
                  },
                )
              : await _executor.execute(
                  call,
                  onWaitingForUser: (actionResult) {
                    steps[steps.length - 1] = steps.last.copyWith(
                      resultJson: jsonEncode({
                        ...actionResult.output,
                        'userAction': {
                          'pending': true,
                          'instruction': call.userAction,
                        },
                      }),
                    );
                    onStepsChanged(List.unmodifiable(steps));
                  },
                );
          if (result.output.containsKey('userAction'))
            userHandoffOccurred = true;
          await onToolCompleted?.call(result);
          final status =
              result.output['pending'] == true &&
                  result.output['newQuestionShown'] != false
              ? AgentStepStatus.running
              : result.status == ToolResultStatus.success
              ? AgentStepStatus.completed
              : result.status == ToolResultStatus.cancelled
              ? AgentStepStatus.cancelled
              : AgentStepStatus.failed;
          steps[steps.length - 1] = steps.last.copyWith(
            status: status,
            detail: _stepDetail(result),
            resultJson: jsonEncode(
              result.toolName == 'getNotifications'
                  ? {'contentRetention': 'task_only'}
                  : result.output,
            ),
          );
          onStepsChanged(List.unmodifiable(steps));
          _throwIfCancelled();
          nextResults.add(result);
          if (endsRun?.call(result) == true) {
            return AgentRunResult(answer: '', steps: List.unmodifiable(steps));
          }
        }
        toolResults = nextResults;
      }
    } finally {
      if (task != null && (await task.read())['status'] == 'active') {
        await task.pause(_cancelRequested ? '用户停止了当前执行' : '执行已中断，等待继续');
      }
      await questions?.cancel();
      for (final update in questions?.takeUpdates() ?? const <ToolResult>[]) {
        await onToolCompleted?.call(update);
      }
    }
  }

  Future<void> cancel() async {
    _cancelRequested = true;
    await Future.wait(<Future<void>>[
      _provider.cancel(),
      _executor.cancel(),
      if (_registry.find('askUser') case final AskUserTool questions)
        questions.cancel(),
    ]);
  }

  void _throwIfCancelled() {
    if (_cancelRequested) {
      throw const AgentCancelled();
    }
  }

  String _stepDetail(ToolResult result) {
    if (result.toolName == 'openModelTopUp' &&
        result.status == ToolResultStatus.success) {
      return '已打开充值页，尚未付款';
    }
    if (result.toolName == 'askUser' &&
        result.status == ToolResultStatus.success) {
      return result.output['pending'] == true
          ? '等待回答'
          : result.output['skipped'] == true
          ? '已跳过问题'
          : '已收到回答';
    }
    return switch (result.status) {
      ToolResultStatus.success => '检查完成',
      ToolResultStatus.cancelled => '已停止',
      ToolResultStatus.denied => '未获用户确认',
      ToolResultStatus.error => '检查未完成',
    };
  }
}
