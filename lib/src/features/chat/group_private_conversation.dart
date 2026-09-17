part of 'chat_controller.dart';

extension GroupPrivateConversation on ChatController {
  bool get canStartPrivateDuringGroup =>
      _groupDispatcher != null &&
      !_groupDispatcher!.closed &&
      _privateConversation == null &&
      activeConversation.kind == ConversationKind.direct &&
      !_submitting &&
      !_claimingSchedule;

  Future<void> _runPrivateDuringGroup() async {
    final conversation = activeConversation;
    _privateConversation = conversation;
    _notifyRun(conversation);
    try {
      await _executeMember(
        conversation,
        reply: await _directReplyContext(conversation),
      );
    } finally {
      _privateConversation = null;
      _resumeForwardedReply();
      _drainGroupSystemNotices();
      _notifyRun(conversation);
    }
  }
}
