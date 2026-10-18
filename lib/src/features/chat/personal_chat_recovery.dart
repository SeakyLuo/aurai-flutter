part of 'chat_controller.dart';

extension PersonalChatRecovery on ChatController {
  Future<void> _retryPersonalChatMessage(
    AgentMessage message, {
    required bool resumeAutoReply,
    Future<void> Function()? beforeRemoval,
  }) => _inConversation(activeConversation, () async {
    if (!canOfferFailedRetry(message)) throw StateError('这条消息当前不能重试');
    final conversation = activeConversation;
    _submitting = true;
    _notifyRun(conversation);
    try {
      final reply = await _directReplyContext(conversation);
      if (!reply.config.isConfigured) {
        throw StateError('请先配置 ${reply.sender.name} 使用的模型');
      }
      final options = await _loadFailedRecoveryOptions(conversation, [message]);
      final continuation = options[message.id] == true ? message.runId : null;
      if (continuation != null) {
        await loadFailedRunProtocol(
          _store.database,
          conversation.id,
          reply.senderId,
          continuation,
          reply.config,
        );
      }
      await _groupSleeps.remove(conversation.id, reply.senderId);
      await beforeRemoval?.call();
      await _removeFailedGroupMessage(conversation, message);
      _recoveryOptions[this] = null;
      _runningConversation = conversation;
      _submitting = false;
      await _executePrivateMember(
        conversation,
        reply: reply,
        continuationRunId: continuation,
        preserveAutoReplyPause: !resumeAutoReply,
      );
    } finally {
      _submitting = false;
      _runningConversation = null;
      _resumeForwardedReply();
      _notifyRun(conversation);
    }
  });
}
