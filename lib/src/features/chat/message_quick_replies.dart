part of 'chat_controller.dart';

extension MessageQuickReplies on ChatController {
  static final _pendingQuickReplies = <String, Object>{};

  Future<bool> submitQuickReply(
    AgentMessage source,
    String key,
    String text,
  ) async {
    final conversation = activeConversation;
    final pendingKey = '${conversation.id}:${source.id}';
    if (_pendingQuickReplies.containsKey(pendingKey)) return false;
    final token = Object();
    _pendingQuickReplies[pendingKey] = token;
    try {
      return await _inConversation(
        conversation,
        () => _submitQuickReply(source, key, text),
      );
    } finally {
      if (identical(_pendingQuickReplies[pendingKey], token)) {
        _pendingQuickReplies.remove(pendingKey);
      }
    }
  }

  Future<bool> _submitQuickReply(
    AgentMessage source,
    String key,
    String text,
  ) async {
    final conversation = activeConversation;
    if ((source.role != AgentMessageRole.assistant &&
            source.senderId != MessageSender.localUser.id) ||
        source.isSystem ||
        source.isReasoning) {
      throw StateError('这条消息不支持快捷回复');
    }
    final sendAsMessage =
        conversation.kind == ConversationKind.direct &&
        source.role == AgentMessageRole.assistant;
    final own = source.quickReplies
        .where(
          (reply) =>
              reply.senderId == MessageSender.localUser.id && reply.key == key,
        )
        .firstOrNull;
    if (own != null && !sendAsMessage) {
      await _removeQuickReply(conversation, source.id, own.id);
      _notifyRun(conversation);
      return false;
    }
    if (source.senderId == MessageSender.localUser.id) {
      final message = _quickReplyMessage(source, key, text);
      _attachQuickReply(
        conversation,
        source.id,
        MessageQuickReply(
          id: message.id,
          senderId: message.senderId,
          key: key,
          text: text,
          createdAt: message.createdAt,
        ),
      );
      conversation.messages.add(message);
      conversation.messageCount++;
      try {
        await _store.writer.save(conversation, makeActive: false);
      } on Object {
        _detachQuickReply(conversation, source.id, message.id);
        conversation.messages.removeWhere((item) => item.id == message.id);
        conversation.messageCount--;
        rethrow;
      }
      QuickReplyRecents.record(key);
      _notifyRun(conversation);
      return false;
    }
    if (conversation.kind == ConversationKind.group) {
      final members = await _store.groups.members(conversation.id);
      if (!members.any((member) => member.sender.id == source.senderId)) {
        throw StateError('该成员已不在群聊中');
      }
    }
    if (canSendToRunningGroup) {
      await _appendRunningGroupQuickReply(source, key, text);
      QuickReplyRecents.record(key);
      return false;
    }
    final queueReply = hasRunningTask && !canStartPrivateDuringGroup;
    final previousPending = conversation.pendingGoal;
    final previousQueued = _execution.queuedUserMessageId;

    cancelSearchNavigation();
    _submitting = true;
    final message = sendAsMessage
        ? AgentMessage(
            id: newMessageId(),
            role: AgentMessageRole.user,
            senderId: MessageSender.localUser.id,
            text: text,
            createdAt: DateTime.now(),
          )
        : _quickReplyMessage(source, key, text);
    final attached = MessageQuickReply(
      id: message.id,
      senderId: message.senderId,
      key: key,
      text: text,
      createdAt: message.createdAt,
    );
    try {
      if (!sendAsMessage) _attachQuickReply(conversation, source.id, attached);
      conversation.messages.add(message);
      conversation.messageCount++;
      conversation.pendingGoal = text;
      if (queueReply && conversation.kind == ConversationKind.direct)
        _execution.queuedUserMessageId = message.id;
      if (!queueReply) {
        conversation.steps.clear();
        conversation.liveToolSteps.clear();
        conversation.errorDetail = null;
        conversation.runState = ChatRunState.idle;
      }
      _notifyRun(conversation);
      try {
        await _store.writer.save(
          conversation,
          recipients: conversation.kind == ConversationKind.group
              ? {
                  message.id: [source.senderId],
                }
              : const {},
        );
      } on Object {
        if (!sendAsMessage)
          _detachQuickReply(conversation, source.id, message.id);
        conversation.messages.removeWhere((item) => item.id == message.id);
        conversation.messageCount--;
        conversation.pendingGoal = previousPending;
        if (_execution.queuedUserMessageId == message.id)
          _execution.queuedUserMessageId = previousQueued;
        rethrow;
      }
      QuickReplyRecents.record(key);
      _updateConversationList(conversation);
      _pendingQuickReplies.remove('${conversation.id}:${source.id}');
      if (queueReply) {
        await _queueSubmittedReply(conversation, message);
        return false;
      }
      if (needsReplyConfiguration) return true;
      _submitting = false;
      if (conversation.kind == ConversationKind.group) {
        await _continueTargetedGroupQuickReply({source.senderId});
      } else {
        await continuePending();
      }
      return false;
    } finally {
      _submitting = false;
      _resumeForwardedReply();
      _drainGroupSystemNotices();
      _notifyRun(conversation);
    }
  }

  Future<void> _appendRunningGroupQuickReply(
    AgentMessage source,
    String key,
    String text,
  ) async {
    final conversation = activeConversation;
    final dispatcher = _groupDispatcher!;
    final message = _quickReplyMessage(source, key, text);
    final attached = MessageQuickReply(
      id: message.id,
      senderId: message.senderId,
      key: key,
      text: text,
      createdAt: message.createdAt,
    );
    dispatcher.hold();
    _submitting = true;
    _attachQuickReply(conversation, source.id, attached);
    conversation.messages.add(message);
    conversation.messageCount++;
    try {
      await _store.writer.save(
        conversation,
        makeActive: false,
        recipients: {
          message.id: [source.senderId],
        },
      );
      dispatcher.receiveTargeted([message], {source.senderId});
      _notifyRun(conversation);
    } on Object {
      _detachQuickReply(conversation, source.id, message.id);
      conversation.messages.removeWhere((item) => item.id == message.id);
      conversation.messageCount--;
      rethrow;
    } finally {
      dispatcher.release();
      _submitting = false;
      _drainGroupSystemNotices();
      _notifyRun(conversation);
    }
  }

  AgentMessage _quickReplyMessage(
    AgentMessage source,
    String key,
    String text,
  ) {
    final quote =
        MessageQuote(
            messageId: source.id,
            senderId: source.senderId,
            text: [
              if (source.images.isNotEmpty) '[图片]',
              for (final file in source.files) '[文件] ${file.name}',
              if (source.text.isNotEmpty)
                String.fromCharCodes(source.text.runes.take(1000)),
            ].join(' '),
          )
          ..senderName = source.senderId == MessageSender.localUser.id
              ? MessageSender.localUser.name
              : source.sender?.name ?? 'AI';
    return AgentMessage(
      id: newMessageId(),
      role: AgentMessageRole.user,
      senderId: MessageSender.localUser.id,
      text: text,
      quote: quote,
      quickReplyToId: source.id,
      quickReplyKey: key,
      createdAt: DateTime.now(),
    );
  }

  void _attachQuickReply(
    Conversation conversation,
    String sourceId,
    MessageQuickReply reply,
  ) {
    for (final list in [
      conversation.messages,
      if (conversation.searchMessages != null) conversation.searchMessages!,
    ]) {
      final index = list.indexWhere((message) => message.id == sourceId);
      if (index < 0) continue;
      list[index] = list[index].withQuickReplies([
        ...list[index].quickReplies,
        reply,
      ]);
    }
  }

  void _detachQuickReply(
    Conversation conversation,
    String sourceId,
    String replyId,
  ) {
    for (final list in [
      conversation.messages,
      if (conversation.searchMessages != null) conversation.searchMessages!,
    ]) {
      final index = list.indexWhere((message) => message.id == sourceId);
      if (index < 0) continue;
      list[index] = list[index].withQuickReplies([
        for (final reply in list[index].quickReplies)
          if (reply.id != replyId) reply,
      ]);
    }
  }

  Future<void> _removeQuickReply(
    Conversation conversation,
    String sourceId,
    String replyId,
  ) async {
    await _store.writer.mutate(() async {
      await _store.database.transaction((txn) async {
        await txn.delete(
          'messages',
          where: "id = ? AND conversation_id = ? AND kind = 'quick_reply'",
          whereArgs: [replyId, conversation.id],
        );
        await txn.rawUpdate(
          'UPDATE conversations SET message_count = (SELECT COUNT(*) FROM messages WHERE conversation_id = ?) WHERE id = ?',
          [conversation.id, conversation.id],
        );
        await txn.delete(
          'app_state',
          where: 'key = ?',
          whereArgs: ['context_summary:${conversation.id}'],
        );
      });
      _store.writer.invalidateHistory(
        conversation.id,
        deletedMessageId: replyId,
      );
      for (final value in _interactiveConversations(
        conversation.id,
        conversation,
      )) {
        _detachQuickReply(value, sourceId, replyId);
        value.messages.removeWhere((message) => message.id == replyId);
        value.messageCount--;
        value.contextSummary = null;
        value.sharedContext = null;
      }
      final execution = _executionStates[conversation.id];
      execution?.groupDispatcher?.history.removeWhere(
        (message) => message.id == replyId,
      );
      if (execution?.queuedUserMessageId == replyId) {
        execution!.queuedUserMessageId = null;
        conversation.pendingGoal = null;
      }
    });
    _updateConversationList(conversation);
    _notifyRun(conversation);
  }

  Future<Map<String, Object?>> _sendAiQuickReply(
    Conversation conversation,
    String actor,
    String sourceId,
    String key,
  ) async {
    final text = quickReplyTexts[key];
    if (text == null) throw StateError('不支持的快捷回复');
    await _store.writer.flush();
    final rows = await _store.database.query(
      'messages',
      where:
          "id = ? AND conversation_id = ? AND kind NOT IN ('system', 'reasoning', 'quick_reply') AND conversation_id IN (SELECT conversation_id FROM conversation_members WHERE sender_id = ? AND left_at IS NULL) AND (interactive_json IS NULL OR json_extract(interactive_json, '\$.participation.audience') IS NULL OR EXISTS (SELECT 1 FROM json_each(interactive_json, '\$.participation.audience') WHERE value = ?))",
      whereArgs: [sourceId, conversation.id, actor, actor],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('消息不存在或不可见');
    final existing = await _store.database.query(
      'message_quick_replies',
      where: 'parent_message_id = ? AND actor_id = ? AND reply_key = ?',
      whereArgs: [sourceId, actor, key],
    );
    if (existing.isNotEmpty) return {'sent': true};
    final senderIds = {actor, rows.single['sender_id'] as String};
    final senderRows = await _store.database.query(
      'message_senders',
      where: 'id IN (${List.filled(senderIds.length, '?').join(',')})',
      whereArgs: senderIds.toList(),
    );
    final senders = {
      for (final row in senderRows)
        row['id'] as String: MessageSender.fromRow(row),
    };
    final message = AgentMessage(
      id: newMessageId(),
      role: AgentMessageRole.assistant,
      senderId: actor,
      sender: senders[actor]!,
      text: text,
      createdAt: DateTime.now(),
      quickReplyToId: sourceId,
      quickReplyKey: key,
      quote: MessageQuote(
        messageId: sourceId,
        senderId: rows.single['sender_id'] as String,
        text: String.fromCharCodes(
          (rows.single['text'] as String).runes.take(1000),
        ),
      )..senderName = senders[rows.single['sender_id']]!.name,
    );
    await _store.database.transaction((txn) async {
      await txn.insert('messages', messageRow(conversation.id, message));
      await txn.insert('message_quick_replies', {
        'message_id': message.id,
        'parent_message_id': sourceId,
        'actor_id': actor,
        'reply_key': key,
      });
      await txn.rawUpdate(
        'UPDATE conversations SET message_count = message_count + 1 WHERE id = ?',
        [conversation.id],
      );
    });
    for (final value in _interactiveConversations(
      conversation.id,
      conversation,
    )) {
      _attachQuickReply(
        value,
        sourceId,
        MessageQuickReply(
          id: message.id,
          senderId: actor,
          key: key,
          text: text,
          createdAt: message.createdAt,
        ),
      );
    }
    _publishInteractiveChange(conversation.id, message, source: conversation);
    return {'sent': true, 'messageId': message.id};
  }

  Future<void> _continueTargetedGroupQuickReply(Set<String> recipients) async {
    final conversation = activeConversation;
    _runningConversation = conversation;
    _notifyRun(conversation);
    try {
      await _executeGroupChat(conversation, wakeMembers: recipients);
    } finally {
      _runningConversation = null;
      _resumeForwardedReply();
      _drainGroupSystemNotices();
      _updateConversationList(conversation);
      _notifyRun(conversation);
    }
  }
}
