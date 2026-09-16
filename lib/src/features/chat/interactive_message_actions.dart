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
      _publishInteractiveChange(
        source.id,
        message,
        source: source,
        notifyParticipants: true,
      );
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
    if (operation == 'readInteractiveMessage') {
      final perspective = args['participantId'] as String? ?? senderId;
      if (perspective != senderId && !old.visible('visibility'))
        throw StateError('这条消息尚未公开其他参与者的选择');
      return {
        'messageId': id,
        ...old.readFor(senderId),
        'perspective': old.viewFor(perspective).toJson(),
        'history': await readInteractiveHistory(
          _store.database,
          id,
          perspective,
          before: args['beforeEvent'] as int?,
        ),
      };
    }
    if (operation == 'clickInteractiveMessage') {
      final actor = await groupStore.loadAi(senderId);
      final result = await InteractiveMessageStore(_store.database).click(
        source.id,
        id,
        args['buttonId'] as String,
        args['revision'] as int,
        actor: actor.sender,
        participantRevision: args['participantRevision'] as int,
      );
      _replaceInteractiveCard(source.id, id, result.card, source: source);
      if (result.notice != null)
        _publishInteractiveChange(source.id, result.notice!, source: source);
      MessageCallbacks.changes.add(null);
      return {
        'messageId': id,
        ...result.card.readFor(senderId),
        if (result.url != null) 'url': result.url,
      };
    }
    if (row['sender_id'] != senderId) throw StateError('只能更新自己发送的交互消息');
    if (args['revision'] != old.revision) throw StateError('消息已更新，请先重新读取');
    final definitionChanged = ['title', 'body', 'buttons', 'states'].any(
      (key) =>
          jsonEncode(old.toJson()[key]) !=
          jsonEncode(args[key] ?? old.toJson()[key]),
    );
    final card = InteractiveMessage.fromJson({
      ...old.toJson(),
      ...args,
      'participation': {
        ...old.participation,
        ...?args['participation'] as Map<String, Object?>?,
      },
      'participants': {
        for (final entry in old.participants.entries)
          entry.key: definitionChanged
              ? (Map<String, Object?>.of(entry.value)
                  ..remove('title')
                  ..remove('body')
                  ..remove('buttons'))
              : entry.value,
      },
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
          'interactive_json': jsonEncode(
            card.toJson(includeParticipants: true),
          ),
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
    _viewConversation,
    if (_runningConversation != null) _runningConversation!,
    if (_privateConversation != null) _privateConversation!,
    ..._groupRuns.values,
    if (_executionStates[id]?.conversation case final target?) target,
    if (_executionStates[id]?.runningConversation case final running?) running,
    if (_executionStates[id]?.privateConversation case final private?) private,
    ...?_executionStates[id]?.groupRuns.values,
    ..._conversations,
    ..._searchWindows.values,
  }.where((c) => c.id == id);

  void _replaceInteractiveCard(
    String conversationId,
    String id,
    InteractiveMessage card, {
    Conversation? source,
  }) {
    InteractiveMessageStore.changes.add(id);
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
    final dispatcher = _executionStates[conversationId]?.groupDispatcher;
    if (dispatcher != null) {
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
    bool notifyParticipants = false,
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
    final dispatcher = _executionStates[conversationId]?.groupDispatcher;
    if (dispatcher != null &&
        !dispatcher.history.any((m) => m.id == message.id)) {
      if (notifyParticipants && !dispatcher.closed && !dispatcher.stopped) {
        dispatcher.receive([message]);
      } else {
        dispatcher.history.add(message);
      }
    } else if (notifyParticipants && source?.kind == ConversationKind.group) {
      unawaited(
        _receiveGroupSystemNotice(conversationId, message).catchError((
          Object error,
        ) {
          developer.log('Interactive message dispatch failed', error: error);
        }),
      );
    }
    _conversationChanged();
  }

  Future<InteractiveClickResult> clickInteractiveMessage(
    String messageId,
    String buttonId,
    int revision,
    int participantRevision,
  ) async {
    final conversation = activeConversation;
    await _store.writer.flush();
    try {
      final result = await InteractiveMessageStore(_store.database).click(
        conversation.id,
        messageId,
        buttonId,
        revision,
        actor: MessageSender.localUser,
        participantRevision: participantRevision,
      );
      _replaceInteractiveCard(conversation.id, messageId, result.card);
      if (result.notice != null)
        _publishInteractiveChange(conversation.id, result.notice!);
      MessageCallbacks.changes.add(null);
      return (card: result.card, url: result.url);
    } on InteractiveMessageChanged catch (error) {
      _replaceInteractiveCard(conversation.id, messageId, error.card);
      rethrow;
    }
  }
}
