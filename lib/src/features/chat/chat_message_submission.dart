part of 'chat_page.dart';

extension ChatMessageSubmission on _ChatPageState {
  Future<void> _send() async {
    final conversationId = widget.controller.activeConversation.id;
    final goal = _textController.text.trim();
    if ((goal.isEmpty &&
            widget.controller.draftImages.isEmpty &&
            widget.controller.draftFiles.isEmpty) ||
        widget.controller.addingImages ||
        _preparingGoal) {
      return;
    }
    _draftTimer?.cancel();
    if (widget.controller.shouldQueuePrivateMessage) {
      try {
        await widget.controller.submitGoal(goal);
      } on Object catch (error) {
        if (mounted) _showRunNotice(error);
      }
      return;
    }
    if (widget.controller.activeConversation.kind != ConversationKind.group)
      _focusNode.unfocus();
    if (widget.controller.hasSearchWindow) _scrollToBottom();
    _beforeSentMessageId = widget.controller.messages.lastOrNull?.id;
    _positionSentMessage =
        widget.controller.activeConversation.kind != ConversationKind.group;
    if (!_positionSentMessage) {
      _sentMessageId = null;
      _scrollToBottom();
    }
    try {
      final needsSettings = await widget.controller.submitGoal(
        goal,
        mentionedRecipients: _mentionedRecipients,
      );
      if (needsSettings && mounted) {
        _preparingGoal = true;
        await _openSettings(continueAfterSave: true);
      }
    } on Object catch (error) {
      if (widget.controller.activeConversation.id == conversationId)
        _showRunNotice(error);
    } finally {
      _preparingGoal = false;
      _positionSentMessage = false;
    }
  }

  Future<void> _sendQuickReply(AgentMessage message, String key) async {
    final conversationId = widget.controller.activeConversation.id;
    try {
      final needsSettings = await widget.controller.submitQuickReply(
        message,
        key,
      );
      if (needsSettings && mounted) {
        _preparingGoal = true;
        await _openSettings(continueAfterSave: true);
      }
    } on Object catch (error) {
      if (widget.controller.activeConversation.id == conversationId) {
        _showRunNotice(error);
      }
    } finally {
      _preparingGoal = false;
    }
  }

  Future<void> _sendQueuedMessages(String messageId) async {
    final controller = widget.controller;
    final conversationId = controller.activeConversation.id;
    try {
      final needsSettings = await controller.sendPendingMessages(
        messageId: messageId,
      );
      if (needsSettings && mounted) {
        final saved = await ModelSettingsSheet.show(
          context,
          controller: controller,
          continueAfterSave: false,
        );
        if (saved &&
            mounted &&
            controller.activeConversation.id == conversationId) {
          await controller.sendPendingMessages(messageId: messageId);
        }
      }
    } on Object catch (error) {
      if (mounted && controller.activeConversation.id == conversationId) {
        _showRunNotice(error);
      }
    }
  }
}
