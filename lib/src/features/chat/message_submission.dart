part of 'chat_controller.dart';

extension MessageSubmission on ChatController {
  Future<bool> submitGoal(String goal, {List<String>? mentionedRecipients}) =>
      _inConversation(
        activeConversation,
        () => _submitGoal(goal, mentionedRecipients),
      );

  Future<bool> _submitGoal(
    String goal,
    List<String>? mentionedRecipients,
  ) async {
    if (shouldQueuePrivateMessage) {
      await _enqueuePrivateMessage(goal, fromDraft: true);
      return false;
    }
    if (canSendToRunningGroup) {
      await _appendGroupMessage(goal, mentionedRecipients);
      return false;
    }
    final queueReply = hasRunningTask && !canStartPrivateDuringGroup;
    cancelSearchNavigation();
    _submitting = true;
    _notifyRun(activeConversation);
    final wasNew =
        activeConversation.kind == ConversationKind.direct &&
        activeConversation.messageCount == 0 &&
        !activeConversation.isTemporary &&
        !activeConversation.isStored;
    final previousPending = activeConversation.pendingGoal;
    final previousQueued = _execution.queuedUserMessageId;
    final messageId = newMessageId();
    final previousQuote = activeConversation.draftQuote;
    final previousDraft = activeConversation.draft;
    final previousMentions = List.of(activeConversation.draftMentions);
    final previousTitle = activeConversation.storedTitle;
    try {
      final recipients = activeConversation.kind == ConversationKind.group
          ? (await _store.groups.members(activeConversation.id))
                .where(
                  (member) =>
                      member.sender.kind == MessageSenderKind.agent &&
                      (mentionedRecipients == null ||
                          mentionedRecipients.contains(member.sender.id)),
                )
                .map((member) => member.sender.id)
                .toList()
          : const <String>[];
      if (wasNew) await _newDraftStore.save(activeConversation);
      activeConversation.draft = '';
      activeConversation.draftMentions.clear();
      activeConversation.draftQuote = null;
      if (activeConversation.messageCount == 0 && previousTitle == '新会话') {
        activeConversation.storedTitle = null;
      }
      messages.add(
        AgentMessage(
          id: messageId,
          role: AgentMessageRole.user,
          senderId: MessageSender.localUser.id,
          text: goal,
          quote: previousQuote,
          images: List.unmodifiable(draftImages),
          files: List.unmodifiable(draftFiles),
          createdAt: DateTime.now(),
        ),
      );
      activeConversation.messageCount++;
      draftImages.clear();
      draftFiles.clear();
      pendingGoal = goal;
      if (queueReply && activeConversation.kind == ConversationKind.direct)
        _execution.queuedUserMessageId = messageId;
      if (!queueReply) {
        steps.clear();
        errorDetail = null;
        runState = ChatRunState.idle;
      }
      _notifyRun(activeConversation);
      try {
        await _persist(
          saveRuntime: true,
          saveMessages: true,
          recipients: activeConversation.kind == ConversationKind.group
              ? {messageId: recipients}
              : const {},
        );
      } on Object {
        final index = messages.indexWhere((message) => message.id == messageId);
        final unsent = messages.removeAt(index);
        activeConversation.messageCount--;
        activeConversation.draft = previousDraft;
        activeConversation.draftMentions
          ..clear()
          ..addAll(previousMentions);
        activeConversation.draftQuote = previousQuote;
        activeConversation.storedTitle = previousTitle;
        draftImages.addAll(unsent.images);
        draftFiles.addAll(unsent.files);
        pendingGoal = previousPending;
        if (_execution.queuedUserMessageId == messageId)
          _execution.queuedUserMessageId = previousQueued;
        rethrow;
      }
      if (wasNew) {
        if (activeConversation.defaultSenderId == MessageSender.aurai.id) {
          _newConversation = Conversation.empty();
        }
        await _newDraftStore.clear(
          senderId: activeConversation.defaultSenderId,
        );
      }
      _updateConversationList();
      if (queueReply) {
        await _queueSubmittedReply(
          activeConversation,
          messages.firstWhere((message) => message.id == messageId),
        );
        return false;
      }
      if (needsReplyConfiguration) {
        return true;
      }
      _submitting = false;
      await continuePending();
      return false;
    } finally {
      _submitting = false;
      _resumeForwardedReply();
      _drainGroupSystemNotices();
      _notifyRun(activeConversation);
    }
  }

  Future<void> _queueSubmittedReply(
    Conversation conversation,
    AgentMessage message,
  ) async {
    if (conversation.kind == ConversationKind.group) {
      if (_groupDispatcher?.stopped == true) {
        _queuedSystemNotices
            .putIfAbsent(conversation.id, () => [])
            .add(message);
      } else {
        await _receiveGroupSystemNotice(conversation.id, message);
      }
    }
  }

  Future<void> _appendGroupMessage(String goal, List<String>? mentions) async {
    final conversation = activeConversation;
    final dispatcher = _groupDispatcher!;
    dispatcher.hold();
    _submitting = true;
    final message = AgentMessage(
      id: newMessageId(),
      role: AgentMessageRole.user,
      senderId: MessageSender.localUser.id,
      text: goal,
      quote: conversation.draftQuote,
      images: List.unmodifiable(draftImages),
      files: List.unmodifiable(draftFiles),
      createdAt: DateTime.now(),
    );
    final draft = conversation.draft;
    final draftMentions = List.of(conversation.draftMentions);
    conversation.messages.add(message);
    conversation.messageCount++;
    conversation.draft = '';
    conversation.draftMentions.clear();
    conversation.draftQuote = null;
    draftImages.clear();
    draftFiles.clear();
    try {
      await _store.writer.save(
        conversation,
        makeActive: false,
        saveDraft: true,
        recipients: {message.id: mentions ?? _groupReplies.keys.toList()},
      );
      dispatcher.receive(
        [message],
        mentions: {
          ...?mentions,
          if (goal.contains('@所有人')) ..._groupReplies.keys,
        },
      );
      _notifyRun(conversation);
    } on Object {
      conversation.messages.removeWhere((m) => m.id == message.id);
      conversation.messageCount--;
      conversation.draft = draft;
      conversation.draftMentions.addAll(draftMentions);
      conversation.draftQuote = message.quote;
      draftImages.addAll(message.images);
      draftFiles.addAll(message.files);
      rethrow;
    } finally {
      dispatcher.release();
      _submitting = false;
      _drainGroupSystemNotices();
      _notifyRun(conversation);
    }
  }
}
