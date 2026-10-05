import '../domain/tool_models.dart';

/// A tool may acknowledge a call now and deliver its final result later.
/// Updates retain the original call id; a pending acknowledgement is not success.
abstract interface class DeferredAgentTool implements AgentTool {
  bool get hasPending;
  bool get hasUpdates;
  List<ToolResult> takeUpdates();
  Future<void> waitForPending();
}

class DeferredToolExecution {
  DeferredToolExecution({
    required this.initialOutput,
    required Future<ToolResult> Function() finish,
    required this.cancel,
  }) : _finish = finish;
  final Map<String, Object?> initialOutput;
  final Future<ToolResult> Function() _finish;
  Future<ToolResult>? _completion;
  Future<ToolResult> finish() => _completion ??= Future.sync(_finish);
  final Future<void> Function() cancel;
}
