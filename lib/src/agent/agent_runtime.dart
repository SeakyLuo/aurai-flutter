import '../domain/agent_models.dart';
import '../domain/model_provider.dart';
import '../domain/tool_models.dart';
import 'tool_executor.dart';
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
  }) async {
    _cancelRequested = false;
    final steps = <AgentStep>[];
    String? continuationToken;
    var toolResults = const <ToolResult>[];

    for (var turn = 0; turn < 20; turn += 1) {
      _throwIfCancelled();
      final modelTurn = await _provider.respond(
        ModelRequest(
          messages: conversation,
          tools: _registry.availableDefinitions,
          capabilities: _registry.capabilities,
          continuationToken: continuationToken,
          toolResults: toolResults,
        ),
      );
      continuationToken = modelTurn.continuationToken;
      _throwIfCancelled();

      if (modelTurn.toolCalls.isEmpty) {
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
        steps.add(
          AgentStep(
            toolName: call.name,
            title: toolTitle(call.name),
            status: AgentStepStatus.running,
          ),
        );
        onStepsChanged(List.unmodifiable(steps));
        final result = await _executor.execute(call);
        _throwIfCancelled();
        final status = result.status == ToolResultStatus.success
            ? AgentStepStatus.completed
            : AgentStepStatus.failed;
        steps[steps.length - 1] = steps.last.copyWith(
          status: status,
          detail: _stepDetail(result),
        );
        onStepsChanged(List.unmodifiable(steps));
        nextResults.add(result);
      }
      toolResults = nextResults;
    }
    throw const ModelProviderException('任务步骤过多，已停止以便重新规划');
  }

  Future<void> cancel() async {
    _cancelRequested = true;
    await Future.wait(<Future<void>>[_provider.cancel(), _executor.cancel()]);
  }

  void _throwIfCancelled() {
    if (_cancelRequested) {
      throw const AgentCancelled();
    }
  }

  String _stepDetail(ToolResult result) {
    return switch (result.status) {
      ToolResultStatus.success => '检查完成',
      ToolResultStatus.cancelled => '已停止',
      ToolResultStatus.denied => '未获用户确认',
      ToolResultStatus.error => '检查未完成',
    };
  }
}
