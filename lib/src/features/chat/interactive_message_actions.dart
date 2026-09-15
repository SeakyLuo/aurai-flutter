part of 'chat_controller.dart';

extension InteractiveMessageActions on ChatController {
  Future<Map<String, Object?>> _interactiveMessage(
    String operation,
    Map<String, Object?> args,
    Conversation source,
    String senderId,
  ) async {
    await _store.writer.flush();
    final id = args['messageId'] as String?;
    if (operation == 'sendInteractiveMessage') {
      final card = InteractiveMessage.fromJson({...args, 'revision': 0});
      final profile = await groupStore.loadAi(senderId);
      final message = AgentMessage(
        id: newMessageId(),
        role: AgentMessageRole.assistant,
        senderId: senderId,
        sender: profile.sender,
        text: '${card.title}\n${card.body}',
        createdAt: DateTime.now(),
        interactive: card,
        runId: source.activeRunId,
        isGroupMessage: source.kind == ConversationKind.group,
      );
      if (source.kind == ConversationKind.group) {
        _checkGroupStopped(source);
        if (_removedGroupMembers.contains(senderId)) throw AgentCancelled();
      }
      await _store.database.transaction((txn) async {
        await txn.insert('messages', messageRow(source.id, message));
        await txn.rawUpdate(
          'UPDATE conversations SET message_count = message_count + 1, preview = ?, updated_at = ? WHERE id = ?',
          [message.text, message.createdAt.microsecondsSinceEpoch, source.id],
        );
      });
      _publishInteractiveChange(source.id, message, source: source);
      return {'sent': true, 'messageId': message.id, 'revision': 0};
    }
    source = await _messageConversation(id!, senderId, source);
    final rows = await _store.database.query(
      'messages',
      where: 'id = ? AND conversation_id = ?',
      whereArgs: [id, source.id],
      limit: 1,
    );
    if (rows.isEmpty ||
        rows.single['interactive_json'] == null ||
        rows.single['kind'] == 'system') {
      throw StateError('交互消息不存在或已撤回');
    }
    final row = rows.single;
    final old = InteractiveMessage.fromJson(
      jsonDecode(row['interactive_json'] as String) as Map<String, dynamic>,
    );
    if (operation == 'readInteractiveMessage')
      return {'messageId': id, ...old.toJson()};
    if (row['sender_id'] != senderId) throw StateError('只能更新自己发送的交互消息');
    if (args['revision'] != old.revision) throw StateError('消息已更新，请先重新读取');
    final card = InteractiveMessage.fromJson({
      ...args,
      'revision': old.revision + 1,
    });
    if (jsonEncode(old.toJson()..remove('revision')) ==
        jsonEncode(card.toJson()..remove('revision'))) {
      return {'updated': false, 'revision': old.revision};
    }
    final actor = await groupStore.loadAi(senderId);
    final notice = await _store.database.transaction((txn) async {
      final changed = await txn.update(
        'messages',
        {
          'interactive_json': jsonEncode(card.toJson()),
          'text': '${card.title}\n${card.body}',
        },
        where: 'id = ? AND interactive_json = ?',
        whereArgs: [id, row['interactive_json']],
      );
      if (changed != 1) throw StateError('消息已更新，请先重新读取');
      return InteractiveMessageStore.writeNotice(
        txn,
        source.id,
        '${actor.sender.name}更新了“${card.title}”',
      );
    });
    _replaceInteractiveCard(source.id, id, card, source: source);
    _publishInteractiveChange(source.id, notice, source: source);
    return {'updated': true, 'revision': card.revision};
  }

  Iterable<Conversation> _interactiveConversations(
    String id,
    Conversation? source,
  ) => {
    if (source != null) source,
    activeConversation,
    if (_runningConversation != null) _runningConversation!,
    if (_privateConversation != null) _privateConversation!,
    ..._groupRuns.values,
    ..._conversations,
    ..._searchWindows.values,
  }.where((c) => c.id == id);

  void _replaceInteractiveCard(
    String conversationId,
    String id,
    InteractiveMessage card, {
    Conversation? source,
  }) {
    for (final conversation in _interactiveConversations(
      conversationId,
      source,
    )) {
      for (final history in [
        conversation.messages,
        if (conversation.searchMessages != null) conversation.searchMessages!,
      ]) {
        final index = history.indexWhere((m) => m.id == id);
        if (index >= 0) {
          history[index] = history[index].withSender(
            history[index].sender,
            interactive: card,
          );
          _store.writer.remember([history[index]]);
        }
      }
    }
    final dispatcher = _groupDispatcher;
    if (_runningConversation?.id == conversationId && dispatcher != null) {
      final index = dispatcher.history.indexWhere((m) => m.id == id);
      if (index >= 0)
        dispatcher.history[index] = dispatcher.history[index].withSender(
          dispatcher.history[index].sender,
          interactive: card,
        );
    }
    _conversationChanged();
  }

  void _publishInteractiveChange(
    String conversationId,
    AgentMessage message, {
    Conversation? source,
  }) {
    for (final conversation in _interactiveConversations(
      conversationId,
      source,
    )) {
      if (!conversation.messages.any((m) => m.id == message.id)) {
        conversation.messages.add(message);
        conversation.messageCount++;
      }
    }
    _store.writer.remember([message]);
    if (_runningConversation?.id == conversationId &&
        _groupDispatcher != null &&
        !_groupDispatcher!.history.any((m) => m.id == message.id)) {
      _groupDispatcher!.history.add(message);
    }
    _conversationChanged();
  }

  Future<String?> clickInteractiveMessage(
    String messageId,
    String buttonId,
    int revision,
  ) async {
    final conversation = activeConversation;
    await _store.writer.flush();
    final result = await InteractiveMessageStore(
      _store.database,
    ).click(conversation.id, messageId, buttonId, revision);
    _replaceInteractiveCard(conversation.id, messageId, result.card);
    if (result.notice != null)
      _publishInteractiveChange(conversation.id, result.notice!);
    MessageCallbacks.changes.add(null);
    return result.url;
  }
}
