part of 'chat_controller.dart';

extension InteractiveMessageActions on ChatController {
  /// Program-created activities retain normal message semantics and do not wake an AI.
  Future<String> sendSystemInteractiveMessage(
    Map<String, Object?> definition, {
    String? callbackSenderId,
  }) async {
    await _store.writer.flush();
    final conversation = activeConversation;
    final card = InteractiveMessage.fromDefinition({
      ...definition,
      'revision': 0,
      'participation': {
        ...?definition['participation'] as Map<String, Object?>?,
        'presentation': 'system',
      },
    });
    card.validateTransport(html: false);
    final callbacks = [
      ...card.buttons,
      for (final state in card.states)
        ...(state['buttons'] as List).cast<Map>(),
    ].any((b) => b['notifyAi'] == true);
    if (callbacks && callbackSenderId == null)
      throw ArgumentError('配置了 AI 通知时，请指定接收回调的 AI');
    final sender = callbackSenderId == null
        ? MessageSender.localUser
        : (await groupStore.loadAi(callbackSenderId)).sender;
    final message = AgentMessage(
      id: newMessageId(),
      role: AgentMessageRole.assistant,
      senderId: sender.id,
      sender: sender,
      text: card.participation['audience'] == null ? card.title : '私密交互消息',
      interactive: card,
      createdAt: DateTime.now(),
      isGroupMessage: conversation.kind == ConversationKind.group,
    );
    await _store.database.transaction((txn) async {
      await txn.insert('messages', messageRow(conversation.id, message));
      await txn.rawUpdate(
        'UPDATE conversations SET message_count = message_count + 1, preview = ?, updated_at = ? WHERE id = ?',
        [
          message.text,
          message.createdAt.microsecondsSinceEpoch,
          conversation.id,
        ],
      );
    });
    _publishInteractiveChange(conversation.id, message, source: conversation);
    return message.id;
  }

  Future<Map<String, Object?>> _interactiveMessage(
    String operation,
    Map<String, Object?> args,
    Conversation source,
    String senderId,
  ) async {
    await _store.writer.flush();
    final id = args['messageId'] as String?;
    if (operation == 'sendInteractiveMessage') {
      final targetId = args['conversationId'] as String? ?? source.id;
      final sameConversation = targetId == source.id;
      final access = await _store.database.query(
        'conversation_members',
        columns: ['sender_id'],
        where: 'conversation_id = ? AND sender_id = ? AND left_at IS NULL',
        whereArgs: [targetId, senderId],
        limit: 1,
      );
      if (access.isEmpty) throw StateError('会话不存在或你无权访问该会话');
      final target = sameConversation ? source : await _forwardTarget(targetId);
      final card = InteractiveMessage.fromDefinition({...args, 'revision': 0});
      card.validateTransport(html: false);
      final profile = await groupStore.loadAi(senderId);
      final message = AgentMessage(
        id: newMessageId(),
        role: AgentMessageRole.assistant,
        senderId: senderId,
        sender: profile.sender,
        text: card.participation['audience'] == null
            ? '${card.title}\n${card.body}'
            : '私密交互消息',
        createdAt: DateTime.now(),
        interactive: card,
        runId: sameConversation ? source.activeRunId : null,
        isGroupMessage: target.kind == ConversationKind.group,
      );
      if (source.kind == ConversationKind.group) {
        _checkGroupStopped(source);
        if (_removedGroupMembers.contains(senderId)) throw AgentCancelled();
      }
      await _store.database.transaction((txn) async {
        await txn.insert('messages', messageRow(target.id, message));
        await txn.rawUpdate(
          'UPDATE conversations SET message_count = message_count + 1, preview = ?, updated_at = ? WHERE id = ?',
          [message.text, message.createdAt.microsecondsSinceEpoch, target.id],
        );
      });
      _publishInteractiveChange(
        target.id,
        message,
        source: target,
        notifyParticipants: !card.systemPresentation,
      );
      return {
        'sent': true,
        'conversationId': target.id,
        'messageId': message.id,
        'revision': 0,
      };
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
    old.requireViewer(senderId);
    if (operation == 'readInteractiveMessage') {
      final perspective = args['participantId'] as String? ?? senderId;
      if (perspective != senderId &&
          !old.visible('visibility', actor: senderId))
        throw StateError('这条消息尚未公开其他参与者的选择');
      if (perspective != senderId &&
          !old.visible('summaryVisibility', actor: senderId))
        throw StateError('当前权限不允许查看其他参与者的历史快照');
      return {
        'messageId': id,
        ...old.readFor(senderId),
        'perspective': {
          ...old.viewFor(perspective).toJson(),
          if (old.hasInteraction)
            'interactionView': old.interactionView(
              perspective,
              viewer: senderId,
            ),
        },
        'history': await readInteractiveHistory(
          _store.database,
          id,
          perspective,
          before: args['beforeEvent'] as int?,
        ),
      };
    }
    if (operation == 'retryInteractiveCallback') {
      final card = await MessageCallbacks(
        _store.database,
      ).retry(id, args['callbackEventId'] as String, senderId);
      _replaceInteractiveCard(source.id, id, card, source: source);
      return {'messageId': id, ...card.readFor(senderId)};
    }
    if (operation == 'updateInteractiveMessage' &&
        args['callbackEventId'] != null) {
      final result = await completeInteractiveCallback(
        _store.database,
        messageId: id,
        senderId: senderId,
        eventId: args['callbackEventId'] as String,
        result: args,
      );
      _replaceInteractiveCard(source.id, id, result.card, source: source);
      return {
        'updated': result.applied,
        'callbackStatus': result.status,
        'revision': result.card.revision,
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
        inputValue: args['value'],
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
    final definitionChanged =
        [
          'title',
          'body',
          'buttons',
          'states',
          'interaction',
          'showStatistics',
          'buttonColumns',
        ].any(
          (key) =>
              jsonEncode(old.toJson()[key]) !=
              jsonEncode(args[key] ?? old.toJson()[key]),
        );
    var card = InteractiveMessage.fromDefinition({
      ...old.toJson(includeParticipants: true),
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
                  ..remove('buttons')
                  ..remove('showStatistics')
                  ..remove('buttonColumns')
                  ..remove('callback'))
              : entry.value,
      },
      'revision': old.revision + 1,
    });
    if (card.shared) {
      final settled = card.engine.settle(closed: card.closed);
      card = InteractiveMessage.fromJson({
        ...card.toJson(includeParticipants: true),
        'session': settled.runtime,
      });
    }
    card.validateTransport(html: row['kind'] == 'html_game');
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
          'text': card.participation['audience'] == null
              ? '${card.title}\n${card.body}'
              : '私密交互消息',
        },
        where: 'id = ? AND interactive_json = ?',
        whereArgs: [id, row['interactive_json']],
      );
      if (changed != 1) throw StateError('消息已更新，请先重新读取');
      if (definitionChanged) {
        await txn.update(
          'message_callbacks',
          {
            'status': 'expired',
            'processed_at': DateTime.now().microsecondsSinceEpoch,
          },
          where:
              'message_id = ? AND actor_id IS NOT NULL AND processed_at IS NULL',
          whereArgs: [id],
        );
      }
      if (card.participation['audience'] != null) return null;
      return InteractiveMessageStore.writeNotice(
        txn,
        source.id,
        '${actor.sender.name}更新了“${card.title}”',
        source: MessageQuote(
          messageId: id,
          senderId: actor.sender.id,
          text: card.title,
        ),
      );
    });
    _replaceInteractiveCard(source.id, id, card, source: source);
    if (notice != null)
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
    if (notifyParticipants &&
        (source?.kind == ConversationKind.group || dispatcher != null)) {
      unawaited(
        _receiveGroupSystemNotice(conversationId, message).catchError((
          Object error,
        ) {
          developer.log('Interactive message dispatch failed', error: error);
        }),
      );
    } else if (dispatcher != null &&
        !dispatcher.history.any((m) => m.id == message.id)) {
      dispatcher.history.add(message);
    }
    _conversationChanged();
  }

  Future<InteractiveMessage> retryInteractiveCallback(
    String messageId,
    String eventId,
  ) async {
    await _store.writer.flush();
    final card = await MessageCallbacks(
      _store.database,
    ).retry(messageId, eventId, MessageSender.localUser.id);
    return card;
  }

  Future<InteractiveClickResult> clickInteractiveMessage(
    String messageId,
    String buttonId,
    int revision,
    int participantRevision, {
    Object? value,
  }) async {
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
        inputValue: value,
      );
      _replaceInteractiveCard(conversation.id, messageId, result.card);
      if (result.notice != null)
        _publishInteractiveChange(
          conversation.id,
          result.notice!,
          source: conversation,
          notifyParticipants:
              result.card.participants[MessageSender.localUser.id]?['callback'] == null,
        );
      MessageCallbacks.changes.add(null);
      return (card: result.card, url: result.url);
    } on InteractiveMessageChanged catch (error) {
      _replaceInteractiveCard(conversation.id, messageId, error.card);
      rethrow;
    }
  }
}
