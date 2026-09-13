import 'dart:async';
import '../domain/tool_models.dart';
import 'tool_executor.dart';
import 'tool_registry.dart';

class GroupToolQueue {
  Future<void> _tail = Future.value();

  Future<ToolResult> run(Future<ToolResult> Function() action) {
    final next = _tail.then((_) => action());
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }
}

class GroupToolExecutor extends ToolExecutor {
  GroupToolExecutor({
    required super.registry,
    required super.confirm,
    required this.queue,
    required this.cancelled,
    required this.waitForInteraction,
  }) : _registry = registry;
  final ToolRegistry _registry;
  final GroupToolQueue queue;
  final bool Function() cancelled;
  final Future<void> Function() waitForInteraction;

  @override
  Future<ToolResult> execute(
    ToolCall call, {
    void Function(ToolResult)? onWaitingForUser,
  }) {
    final tool = _registry.find(call.name);
    final definition = tool?.definition;
    Future<ToolResult> perform() => cancelled()
        ? Future.value(
            ToolResult(
              callId: call.id,
              toolName: call.name,
              status: ToolResultStatus.cancelled,
              output: const {'cancelled': true, 'performed': false},
            ),
          )
        : super.execute(call, onWaitingForUser: onWaitingForUser);
    // Device mutations and user dialogs share one surface; read-only work can overlap.
    final exclusive =
        call.userAction != null ||
        definition?.waitsForUser == true ||
        (tool is ToolConfirmationPolicyAgentTool &&
            (tool as ToolConfirmationPolicyAgentTool).requiresConfirmation(
              call,
            )) ||
        (definition != null &&
            definition.safetyFor(call.arguments) != ToolSafety.readOnly);
    return exclusive
        ? queue.run(() async {
            await waitForInteraction();
            return perform();
          })
        : perform();
  }
}
