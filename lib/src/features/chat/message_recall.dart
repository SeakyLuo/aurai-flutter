part of 'chat_controller.dart';

extension MessageRecall on ChatController {
  Future<void> restoreRecalledDraft(AgentMessage message) async {
    final conversation = activeConversation;
    final saved =
        (await RecalledMessageDrafts.instance.entries)[message.id]
            as Map<String, dynamic>;
    if (!identical(conversation, activeConversation) || !canEditDraft) return;
    if (conversation.draft.isNotEmpty ||
        draftImages.isNotEmpty ||
        draftFiles.isNotEmpty ||
        conversation.draftQuote != null) {
      throw StateError('请先发送或清空当前草稿，再重新编辑');
    }
    final images = <MessageImage>[];
    final files = <MessageFile>[];
    final copied = <File>[];
    try {
      for (final value in saved['images'] as List) {
        final source = File(value['path'] as String);
        final copy = await source.copy(
          '${source.parent.path}/${newMessageId()}_${source.uri.pathSegments.last}',
        );
        copied.add(copy);
        images.add(
          MessageImage(
            path: copy.path,
            mimeType: value['mimeType'] as String,
            name: value['name'] as String?,
          ),
        );
      }
      for (final value in saved['files'] as List) {
        final source = File(value['path'] as String);
        final copy = await source.copy(
          '${source.parent.path}/${newMessageId()}_${source.uri.pathSegments.last}',
        );
        copied.add(copy);
        files.add(
          MessageFile(
            path: copy.path,
            name: value['name'] as String,
            mimeType: value['mimeType'] as String,
            size: value['size'] as int,
          ),
        );
      }
      if (!identical(conversation, activeConversation) ||
          !canEditDraft ||
          conversation.draft.isNotEmpty ||
          draftImages.isNotEmpty ||
          draftFiles.isNotEmpty ||
          conversation.draftQuote != null) {
        throw StateError('草稿已变化，请先处理当前草稿');
      }
      conversation.draft = saved['text'] as String;
      conversation.draftImages.addAll(images);
      conversation.draftFiles.addAll(files);
    } catch (_) {
      for (final file in copied) {
        await file.delete();
      }
      rethrow;
    }
    pendingComposerDraft = conversation.draft;
    _conversationChanged();
    await _store.writer.save(
      conversation,
      makeActive: false,
      saveDraft: true,
      saveMessages: false,
    );
  }

  Future<Conversation> _messageConversation(
    String messageId,
    String senderId,
    Conversation source,
  ) async {
    final rows = await _store.database.query(
      'messages',
      columns: ['conversation_id'],
      where:
          'id = ? AND conversation_id IN '
          '(SELECT conversation_id FROM conversation_members WHERE sender_id = ? AND left_at IS NULL)',
      whereArgs: [messageId, senderId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('消息不存在或你无权访问该会话');
    final id = rows.single['conversation_id'] as String;
    if (id == source.id) return source;
    if (id == activeConversation.id) return activeConversation;
    final live = _liveConversation(id);
    if (live != null) return live;
    final peer = _peerSessions[id];
    if (peer != null) return (await peer).conversation;
    return _store.load(id);
  }

  Future<void> recallMessage(AgentMessage message) async {
    final conversation = activeConversation;
    if (conversation.kind != ConversationKind.group ||
        message.senderId != MessageSender.localUser.id ||
        message.isSystem)
      return;
    await RecalledMessageDrafts.instance.save(message);
    await _recallMessageIn(conversation, message, userInitiated: true);
  }

  Future<void> _recallAiMessage(
    Conversation conversation,
    String senderId,
    String messageId,
  ) async {
    conversation = await _messageConversation(
      messageId,
      senderId,
      conversation,
    );
    final found = await _store.reader.messages(
      conversation.id,
      throughMessageId: messageId,
      limit: 1,
    );
    if (found.isEmpty || found.single.id != messageId) {
      throw StateError('目标会话中未找到这条消息');
    }
    final message = found.single;
    if (message.senderId != senderId ||
        message.role != AgentMessageRole.assistant ||
        message.isSystem) {
      throw StateError('只能撤回自己发送的消息，不能撤回系统消息');
    }
    await _recallMessageIn(conversation, message, userInitiated: false);
    final peer = _peerSessions[conversation.id];
    if (peer != null) {
      final session = await peer;
      final notice = _recallNotice(message, userInitiated: false);
      _replaceRecalled(session.conversation.messages, messageId, notice);
      _replaceRecalled(session.dispatcher.history, messageId, notice);
    }
  }

  Future<void> _recallMessageIn(
    Conversation conversation,
    AgentMessage message, {
    required bool userInitiated,
  }) => _inConversation(
    conversation,
    () => _recallMessageScoped(
      conversation,
      message,
      userInitiated: userInitiated,
    ),
  );

  Future<void> _recallMessageScoped(
    Conversation conversation,
    AgentMessage message, {
    required bool userInitiated,
  }) async {
    if (!_recallingMessages.add(message.id)) return;
    final notice = _recallNotice(message, userInitiated: userInitiated);
    final dispatcher = _runningConversation?.id == conversation.id
        ? _groupDispatcher
        : null;
    final live =
        dispatcher != null && !dispatcher.closed && !dispatcher.stopped;
    if (live) dispatcher.hold();
    try {
      await _store.writer.mutate(() async {
        await _store.database.transaction((txn) async {
          await txn.update(
            'messages',
            {
              'text': notice.text,
              'kind': 'system',
              'quote_json': null,
              'run_id': null,
              'model_turn_id': null,
              'interactive_json': notice.interactive == null
                  ? null
                  : jsonEncode(notice.interactive!.toJson()),
            },
            where: 'id = ? AND conversation_id = ?',
            whereArgs: [message.id, conversation.id],
          );
          await txn.delete(
            'group_pinned_messages',
            where: 'message_id = ?',
            whereArgs: [message.id],
          );
          await txn.delete(
            'group_favorite_messages',
            where: 'message_id = ?',
            whereArgs: [message.id],
          );
          await txn.delete(
            'attachments',
            where: 'message_id = ?',
            whereArgs: [message.id],
          );
          await txn.rawUpdate(
            r"UPDATE messages SET quote_json = json_set(quote_json, '$.text', ?) "
            r"WHERE conversation_id = ? AND json_extract(quote_json, '$.messageId') = ?",
            ['消息已撤回', conversation.id, message.id],
          );
          await txn.rawUpdate(
            r"UPDATE conversations SET draft_quote_json = json_set(draft_quote_json, '$.text', ?) "
            r"WHERE id = ? AND json_extract(draft_quote_json, '$.messageId') = ?",
            ['消息已撤回', conversation.id, message.id],
          );
          await txn.delete(
            'app_state',
            where: 'key = ?',
            whereArgs: ['context_summary:${conversation.id}'],
          );
        });
        _store.writer.invalidateHistory(conversation.id);
        final copies = <Conversation>{
          conversation,
          if (activeConversation.id == conversation.id) activeConversation,
          if (_runningConversation?.id == conversation.id)
            _runningConversation!,
          if (_privateConversation?.id == conversation.id)
            _privateConversation!,
          ..._conversations.where((c) => c.id == conversation.id),
          ..._searchWindows.values.where((c) => c.id == conversation.id),
          if (conversation.kind == ConversationKind.group &&
              _runningConversation?.id == conversation.id)
            ..._groupRuns.values,
        };
        for (final copy in copies) {
          _replaceRecalled(copy.messages, message.id, notice);
          if (copy.searchMessages != null) {
            _replaceRecalled(copy.searchMessages!, message.id, notice);
          }
          if (copy.draftQuote?.messageId == message.id) {
            copy.draftQuote = _recalledQuote(copy.draftQuote!);
          }
          copy.contextSummary = null;
          copy.sharedContext = null;
        }
        if (live) _replaceRecalled(dispatcher.history, message.id, notice);
        _store.writer.remember([notice]);
      });
      await _store.writer.save(
        conversation,
        makeActive: false,
        saveDraft: true,
        saveMessages: false,
      );
      GroupMessageMarks.changes.add(conversation.id);
      HtmlGameSignals.changes.add(message.id);
      if (message.interactive != null)
        InteractiveMessageStore.changes.add(message.id);
      _conversationChanged();
      if (userInitiated && live) {
        dispatcher.start(
          _groupReplies.keys.where(
            (id) =>
                !dispatcher.paused.contains(id) &&
                (notice.interactive?.canView(id) ?? true),
          ),
        );
      } else if (userInitiated) {
        await _receiveGroupSystemNotice(conversation.id, notice);
      }
    } finally {
      _recallingMessages.remove(message.id);
      if (live) dispatcher.release();
    }
  }

  MessageQuote _recalledQuote(MessageQuote quote) => MessageQuote(
    messageId: quote.messageId,
    senderId: quote.senderId,
    text: '消息已撤回',
  )..senderName = quote.senderName;

  AgentMessage _recallNotice(
    AgentMessage message, {
    required bool userInitiated,
  }) {
    final actorName = userInitiated
        ? (memory.nickname.isEmpty
              ? MessageSender.localUser.name
              : memory.nickname)
        : message.sender!.name;
    final text = '${actorName}撤回了一条消息';
    final audience = message.interactive?.participation['audience'];
    return AgentMessage(
      id: message.id,
      role: message.role,
      senderId: message.senderId,
      sender: message.sender,
      text: text,
      createdAt: message.createdAt,
      isSystem: true,
      // Preserve visibility without retaining the recalled card's content or controls.
      interactive: audience == null
          ? null
          : InteractiveMessage(
              revision: message.interactive!.revision,
              title: text,
              body: '',
              buttons: const [],
              participation: {'audience': List<String>.from(audience as List)},
            ),
    );
  }

  void _replaceRecalled(
    List<AgentMessage> messages,
    String id,
    AgentMessage notice,
  ) {
    for (var i = 0; i < messages.length; i++) {
      final m = messages[i];
      if (m.id == id) {
        messages[i] = notice;
      } else if (m.quote?.messageId == id) {
        messages[i] = AgentMessage(
          id: m.id,
          role: m.role,
          senderId: m.senderId,
          sender: m.sender,
          text: m.text,
          createdAt: m.createdAt,
          images: m.images,
          files: m.files,
          taskSummary: m.taskSummary,
          runId: m.runId,
          modelTurnId: m.modelTurnId,
          responseInput: m.responseInput,
          isSystem: m.isSystem,
          isGroupMessage: m.isGroupMessage,
          htmlGame: m.htmlGame,
          interactive: m.interactive,
          isFailure: m.isFailure,
          quote: _recalledQuote(m.quote!),
        );
      }
    }
  }
}
