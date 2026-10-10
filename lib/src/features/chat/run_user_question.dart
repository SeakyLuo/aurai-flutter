part of 'chat_controller.dart';

extension RunUserQuestion on ChatController {
  void _showRunQuestion(
    Conversation conversation,
    Conversation? parent,
    ExecutionReplyContext reply,
    String runId,
    UserQuestion? question, {
    required bool showProgress,
  }) {
    pendingQuestion = question;
    final target = parent ?? conversation;
    if (question == null) {
      target.pendingQuestionPreviews.remove(runId);
    } else {
      final title = question.title?.trim();
      final label = title == null || title.isEmpty ? question.question : title;
      final preview = '${reply.sender.name}：[问题] $label';
      target.pendingQuestionPreviews[runId] =
          target.kind == ConversationKind.group ? preview : '[问题] $label';
      questionNotifications.value = ConversationCompletion(
        conversationId: target.id,
        title: target.title,
        runId: runId,
        reply: preview,
      );
    }
    unawaited(
      _platform.updateAttentionNotification(
        conversation.id,
        'question',
        title: question == null ? null : '等待你的回答',
        body: question?.question,
      ),
    );
    if (question != null && showProgress) {
      unawaited(
        _platform.updateAgentSessionStep(
          '等待你的回答',
          conversationId: conversation.id,
        ),
      );
    }
    _notifyMember(conversation, parent);
  }
}
