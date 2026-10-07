part of 'chat_controller.dart';

extension ConversationRunContinuation on ChatController {
  Future<String> _groupSleepDraft(String key) async {
    final rows = await _store.database.query(
      'app_state',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    return rows.isEmpty ? '' : rows.single['value'] as String;
  }

  Future<List<Map<String, Object?>>> _runContinuation({
    required Conversation conversation,
    required ExecutionReplyContext reply,
    required AgentMessage userMessage,
    required bool direct,
    required bool hasCallbacks,
    String? runId,
  }) {
    if (runId != null) {
      return loadFailedRunProtocol(
        _store.database,
        conversation.id,
        reply.senderId,
        runId,
        reply.config,
      );
    }
    if (direct && !hasCallbacks) {
      return loadTaskContinuationProtocol(
        _store.database,
        conversation.id,
        userMessage.id,
        reply.config,
        reply.senderId,
      );
    }
    return Future.value(const <Map<String, Object?>>[]);
  }
}
