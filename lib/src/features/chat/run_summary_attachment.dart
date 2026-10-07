part of 'chat_controller.dart';

void _attachRunSummary(
  Conversation runConversation,
  Conversation? groupParent,
  List<AgentMessage> messages,
  List<String> runMessageIds,
  List<AgentTaskActivity> activities,
  Stopwatch executionWatch,
  ProjectGitTaskChanges? gitChanges,
) {
  final hasReasoning = activities.any((activity) => activity.isReasoning);
  if (runMessageIds.isNotEmpty &&
      (runConversation.hasExecutionProcess || hasReasoning)) {
    final answerIndex = messages.lastIndexWhere(
      (m) => runMessageIds.contains(m.id),
    );
    final answer = messages[answerIndex];
    final hasFinalAnswer =
        !answer.isReasoning &&
        answer.interactive == null &&
        answer.htmlGame == null &&
        answer.text.isNotEmpty;
    messages[answerIndex] = AgentMessage(
      id: answer.id,
      role: answer.role,
      isGroupMessage: answer.isGroupMessage,
      markdown: answer.markdown,
      isReasoning: answer.isReasoning,
      senderId: answer.senderId,
      sender: answer.sender,
      runId: answer.runId,
      modelTurnId: answer.modelTurnId,
      text: answer.text,
      createdAt: answer.createdAt,
      images: answer.images,
      interactive: answer.messageMetadata,
      htmlGame: answer.htmlGame,
      quote: answer.quote,
      taskSummary: AgentTaskSummary(
        elapsedMilliseconds:
            runConversation.restoredExecutionElapsed.inMilliseconds +
            executionWatch.elapsedMilliseconds,
        isTask: runConversation.hasExecutionProcess,
        intermediateMessageIds: List.unmodifiable(
          groupParent == null && hasFinalAnswer
              ? runMessageIds.where(
                  (id) =>
                      id != answer.id &&
                      !messages.any((m) => m.id == id && m.interactive != null),
                )
              : <String>[],
        ),
        activities: List.unmodifiable(
          groupParent != null
              ? activities.where((a) => a.toolName != null)
              : !hasFinalAnswer
              ? activities.where((a) => a.toolName != null)
              : activities.take(
                  activities.indexWhere(
                    (activity) => activity.messageId == answer.id,
                  ),
                ),
        ),
        gitChanges: gitChanges,
      ),
    );
  }
}
