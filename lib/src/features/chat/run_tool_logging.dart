part of 'chat_controller.dart';

extension RunToolLogging on ChatController {
  Future<void> Function(ToolResult) _runToolCompletionListener(
    Conversation conversation,
    _ReplyContext reply,
    ModelConfig config,
    String runId,
    ProjectRunSnapshots snapshots,
    Map<String, Object?> diagnosticCalls,
  ) => (result) async {
    await _store.runs.finishTool(runId, result);
    await _updateLiveProjectChanges(snapshots, result, runId);
    final argumentShape = diagnosticCalls.remove(result.callId);
    if (result.status != ToolResultStatus.error) return;
    await ExecutionLog.write({
      'event': 'tool_error',
      'conversationId': conversation.id,
      'senderId': reply.senderId,
      'senderName': reply.sender.name,
      'runId': runId,
      'model': config.model,
      'callId': result.callId,
      'tool': result.toolName,
      'argumentShape': argumentShape,
      'result': result.output,
    }, apiKey: config.apiKey);
  };
}
