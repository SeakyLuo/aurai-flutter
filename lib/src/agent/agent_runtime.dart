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
  bool _cancelRequested = false;

  Future<AgentRunResult> run({
    required List<AgentMessage> conversation,
    required AgentStepListener onStepsChanged,
    ContextSummary? contextSummary,
    String Function()? personalContext,
    Future<void> Function(ContextSummary)? onContextSummary,
    FutureOr<void> Function()? onTurnStarted,
    Future<void> Function(ModelTurn)? onTurnCompleted,
    Future<void> Function(ToolCall)? onToolStarted,
    Future<void> Function(ToolResult)? onToolCompleted,
    void Function(String text)? onTextChanged,
  }) async {
    _cancelRequested = false;
    final steps = <AgentStep>[];
    final stepIndices = <String, int>{};
    String? continuationToken;
    var toolResults = const <ToolResult>[];

    final questions = _registry.find('askUser') as AskUserTool?;
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
        await onTurnStarted?.call();
        final modelTurn = await _provider.respond(
          ModelRequest(
            messages: conversation,
            contextSummary: contextSummary,
            personalContext: personalContext?.call() ?? '',
            onContextSummary: onContextSummary,
            onTextChanged: (text) {
              _throwIfCancelled();
              onTextChanged?.call(text);
            },
            tools: _registry.beginTurn(),
            capabilities: _registry.capabilities,
            continuationToken: continuationToken,
            toolResults: toolResults,
            userUpdates: [
              for (final update in updates)
                'Response to the earlier askUser question: ${jsonEncode(update.output)}',
            ],
          ),
        );
        continuationToken = modelTurn.continuationToken;
        _throwIfCancelled();

        if (modelTurn.text != null && modelTurn.text!.isNotEmpty) {
          onTextChanged?.call(modelTurn.text!);
        }

        await onTurnCompleted?.call(modelTurn);
        if (modelTurn.toolCalls.isEmpty) {
          if (questions != null &&
              (questions.hasPending || questions.hasUpdates)) {
            await questions.waitForPending();
            _throwIfCancelled();
            toolResults = const [];
            continue;
          }
          final answer = modelTurn.text;
          if (answer == null || answer.trim().isEmpty) {
            throw const ModelProviderException('模型没有返回可显示的答复');
          }
          return AgentRunResult(
            answer: answer.trim(),
            steps: List.unmodifiable(steps),
          );
        }

        final nextResults = <ToolResult>[];
        for (final call in modelTurn.toolCalls) {
          _throwIfCancelled();
          await onToolStarted?.call(call);
          stepIndices[call.id] = steps.length;
          steps.add(
            AgentStep(
              toolName: call.name,
              title: toolTitle(call.name),
              status: AgentStepStatus.running,
              requestJson: jsonEncode(call.arguments),
            ),
          );
          onStepsChanged(List.unmodifiable(steps));
          final result = await _executor.execute(call);
          await onToolCompleted?.call(result);
          _throwIfCancelled();
          final status =
              result.output['pending'] == true &&
                  result.output['newQuestionShown'] != false
              ? AgentStepStatus.running
              : result.status == ToolResultStatus.success
              ? AgentStepStatus.completed
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
          nextResults.add(result);
        }
        toolResults = nextResults;
      }
    } finally {
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
