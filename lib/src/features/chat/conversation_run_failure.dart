part of 'chat_controller.dart';

final _recordedRunErrors = Expando<String>('recorded run error conversation');

extension ConversationRunFailure on ChatController {
  void _recordRunError(Object error, String conversationId) {
    if (error is Exception || error is Error) {
      _recordedRunErrors[error] = conversationId;
    }
  }

  bool isRecordedRunError(Object error) =>
      (error is Exception || error is Error) &&
      _recordedRunErrors[error] == activeConversation.id;

  bool canOfferFailedRetry(AgentMessage message) =>
      activeConversation.kind == ConversationKind.direct &&
      message.role == AgentMessageRole.assistant &&
      message.runId != null &&
      activeConversation.runState == ChatRunState.failed &&
      activeConversation.activeRunId == message.runId &&
      !hasRunningTask;

  Future<void> retryFailedRun([String? expectedRunId]) => _inConversation(
    activeConversation,
    () => _retryFailedRun(activeConversation, expectedRunId),
  );

  Future<void> _retryFailedRun(
    Conversation conversation,
    String? expectedRunId,
  ) async {
    final runId = conversation.activeRunId;
    if (conversation.kind != ConversationKind.direct ||
        conversation.runState != ChatRunState.failed ||
        runId == null ||
        (expectedRunId != null && expectedRunId != runId)) {
      throw StateError('这次失败回复已不能重试');
    }
    if (hasRunningTask) throw StateError('当前任务还未结束');
    _submitting = true;
    _notifyRun(conversation);
    late String goal;
    late int messageCount;
    try {
      await _store.writer.mutate(() async {
        await _store.database.transaction((txn) async {
          final runs = await txn.query(
            'agent_runs',
            columns: ['status', 'user_message_id'],
            where: 'id = ? AND conversation_id = ?',
            whereArgs: [runId, conversation.id],
          );
          if (runs.isEmpty || runs.single['status'] != 'failed') {
            throw StateError('这次失败回复已不能重试');
          }
          final userMessageId = runs.single['user_message_id'] as String?;
          final goals = await txn.query(
            'messages',
            columns: ['text'],
            where: 'id = ? AND conversation_id = ? AND role = ?',
            whereArgs: [userMessageId, conversation.id, 'user'],
          );
          if (goals.isEmpty) throw StateError('原消息已不存在，无法重试');
          goal = goals.single['text'] as String;
          await txn.rawUpdate(
            'UPDATE conversations SET active_run_id = CASE WHEN active_run_id = ? THEN NULL ELSE active_run_id END, run_state = ?, error_detail = NULL, pending_goal = ? WHERE id = ?',
            [runId, ChatRunState.idle.name, goal, conversation.id],
          );
          await txn.delete('agent_runs', where: 'id = ?', whereArgs: [runId]);
          await txn.delete(
            'app_state',
            where: 'key = ?',
            whereArgs: ['context_summary:${conversation.id}'],
          );
          final counts = await txn.rawQuery(
            'SELECT COUNT(*) AS count FROM messages WHERE conversation_id = ?',
            [conversation.id],
          );
          await txn.rawUpdate(
            "UPDATE conversations SET message_count = ?, preview = (SELECT text FROM messages WHERE conversation_id = ? AND kind NOT IN ('commentary', 'reasoning', 'quick_reply') ORDER BY created_at DESC, id DESC LIMIT 1), updated_at = COALESCE((SELECT MAX(created_at) FROM messages WHERE conversation_id = ?), created_at) WHERE id = ?",
            [
              counts.single['count'],
              conversation.id,
              conversation.id,
              conversation.id,
            ],
          );
          messageCount = counts.single['count'] as int;
        });
      });
    } finally {
      _submitting = false;
      _notifyRun(conversation);
    }
    conversation.messages.removeWhere((message) => message.runId == runId);
    conversation
      ..messageCount = messageCount
      ..pendingGoal = goal
      ..activeRunId = null
      ..runState = ChatRunState.idle
      ..errorDetail = null
      ..executionWatch = null
      ..restoredExecutionElapsed = Duration.zero
      ..hasExecutionProcess = false
      ..executionUserMessageId = null
      ..contextSummary = null
      ..reconnectAttempt = 0;
    conversation.steps.clear();
    conversation.liveToolSteps.clear();
    _store.writer.invalidateHistory(conversation.id);
    _notifyRun(conversation);
    await _continuePending();
  }
}
