part of 'chat_controller.dart';

extension ConversationActions on ChatController {
  Future<List<AgentMessage>> previewConversationMessages(
    String id, {
    AgentMessage? before,
  }) => _store.reader.messages(id, before: before, limit: 50);

  Future<void> _switchConversation(String? id) async {
    if (_submitting || changingConversation)
      throw StateError('请等待当前操作完成，再切换会话');
    if (id == activeConversation.id && !hasSearchWindow) {
      if (activeConversation.kind == ConversationKind.group) {
        await _reloadGroupMessages(activeConversation);
        _conversationChanged();
      }
      return;
    }
    cancelSearchNavigation();
    changingConversation = true;
    _conversationChanged();
    try {
      await archiveTemporaryConversation(activeConversation);
      await _persist();
      _loadedMessageCounts[activeConversation.id] = messages.length;
      final conversation = id == null
          ? _newConversation
          : id == _pendingAiConversation?.id
          ? _pendingAiConversation!
          : _liveConversation(id) != null
          ? _liveConversation(id)!
          : await _store.load(
              id,
              messageLimit:
                  (_loadedMessageCounts[id] ?? 0) <
                      ConversationReader.messagePageSize
                  ? ConversationReader.messagePageSize
                  : _loadedMessageCounts[id]!,
            );
      if (conversation.kind == ConversationKind.group) {
        await _reloadGroupMessages(conversation);
      }
      if (id == null) {
        await _store.selectNewConversation();
      } else {
        if (conversation.kind == ConversationKind.direct &&
            conversation.messageCount == 0 &&
            !conversation.isTemporary &&
            !conversation.isStored) {
          await _newDraftStore.save(conversation);
          await _store.selectNewConversation();
        } else {
          await _store.writer.save(conversation, saveMessages: false);
        }
      }
      final previousIndex = _conversations.indexWhere(
        (item) => item.id == activeConversation.id,
      );
      if (previousIndex >= 0 &&
          activeConversation != _runningConversation &&
          activeConversation != _privateConversation) {
        _conversations[previousIndex] =
            conversationFromRow(conversationRow(activeConversation))
              ..seenRunId = activeConversation.seenRunId
              ..draftFiles.addAll(activeConversation.draftFiles)
              ..draftImages.addAll(activeConversation.draftImages);
      }
      _activeConversation = conversation;
      _pendingAiConversation = null;
      _activeAi = conversation.kind == ConversationKind.direct
          ? await groupStore.loadAi(conversation.defaultSenderId)
          : null;
      _restoreSearchWindow(conversation);
      _store.writer.retain([
        ...conversation.messages,
        for (final state in _executionStates.values)
          if (state.runningConversation != null &&
              state.conversation != conversation)
            ...state.conversation!.messages,
      ]);
      _updateConversationList();
    } finally {
      changingConversation = false;
      _drainGroupSystemNotices();
      _conversationChanged();
    }
  }

  Future<void> _reloadGroupMessages(Conversation conversation) async {
    await _store.writer.flush();
    final latest = await _store.reader.messages(conversation.id);
    final merged =
        {
          for (final message in conversation.messages) message.id: message,
          for (final message in latest) message.id: message,
        }.values.toList()..sort((a, b) {
          final order = a.createdAt.compareTo(b.createdAt);
          return order == 0 ? a.id.compareTo(b.id) : order;
        });
    conversation.messages
      ..clear()
      ..addAll(merged);
  }

  Future<void> saveTemporaryConversation(String id) async {
    final conversation = await _targetConversation(id);
    final previousMode = conversation.mode;
    final previouslyArchived = conversation.isArchived;
    conversation.mode = ConversationMode.normal;
    conversation.isArchived = false;
    try {
      await _store.writer.mutate(() async {
        await _store.database.update(
          'conversations',
          {'mode': ConversationMode.normal.name, 'archived': 0},
          where: 'id = ?',
          whereArgs: [id],
        );
      });
    } on Object {
      conversation.mode = previousMode;
      conversation.isArchived = previouslyArchived;
      rethrow;
    }
    _syncConversationMetadata(conversation, {
      'mode': ConversationMode.normal.name,
      'archived': 0,
    });
    _updateConversationList(conversation);
    _conversationChanged();
  }

  Future<void> archiveTemporaryConversation(Conversation conversation) async {
    if (!conversation.isTemporary) return;
    final previouslyArchived = conversation.isArchived;
    conversation.isArchived = true;
    try {
      await _saveConversationHeader(conversation, {'archived': 1});
    } on Object {
      conversation.isArchived = previouslyArchived;
      rethrow;
    }
    _updateConversationList(conversation);
    _conversationChanged();
  }

  void _updateConversationList([Conversation? value]) {
    final conversation = value ?? activeConversation;
    if (conversation.kind == ConversationKind.direct &&
        conversation.messageCount == 0)
      return;
    final index = _conversations.indexWhere(
      (item) => item.id == conversation.id,
    );
    if (index == -1) {
      _conversations.add(conversation);
    } else {
      _conversations[index] = conversation;
    }
  }

  Future<void> _reloadConversations() async {
    final page = await _store.reader.list();
    _conversations
      ..clear()
      ..addAll(
        page.map(
          (item) => item.id == activeConversation.id
              ? activeConversation
              : _liveConversation(item.id) != null
              ? _liveConversation(item.id)!
              : item,
        ),
      );
    _conversationCursor = page.isEmpty ? null : page.last;
    hasMoreConversations = page.length == ConversationReader.pageSize;
  }

  Future<void> markActiveConversationRead() async {
    final conversation = activeConversation;
    if (conversation.kind == ConversationKind.group) {
      if (!conversation.needsGroupReadCheckpoint) return;
      final latest = conversation.messages.last;
      await _store.writer.flush();
      await GroupUnreadMessages(_store.database).markRead(conversation, latest);
      _updateConversationList();
      _conversationChanged();
      return;
    }
    if (conversation.activeRunId == null ||
        conversation.seenRunId == conversation.activeRunId)
      return;
    final previous = conversation.seenRunId;
    conversation.seenRunId = conversation.activeRunId;
    try {
      await _store.writer.markRunRead(conversation.id, conversation.seenRunId!);
    } on Object {
      conversation.seenRunId = previous;
      rethrow;
    }
    _updateConversationList();
    _conversationChanged();
  }

  Future<Conversation> _targetConversation(String? id) async {
    if (id == null || id == activeConversation.id) return activeConversation;
    final live = _liveConversation(id);
    if (live != null) return live;
    for (final conversation in _conversations) {
      if (conversation.id == id) return conversation;
    }
    return _store.load(id);
  }

  Future<List<Conversation>> archivedConversations({Conversation? after}) =>
      _store.reader.list(after: after, archived: true);

  Future<void> setConversationArchived(
    String id, {
    required bool archived,
  }) async {
    final conversation = await _targetConversation(id);
    final previous = conversation.isArchived;
    if (archived &&
        conversation.id == activeConversation.id &&
        (_submitting || changingConversation)) {
      throw StateError('请等待当前操作完成，再归档会话');
    }
    conversation.isArchived = archived;
    try {
      await _saveConversationHeader(conversation, {
        'archived': conversation.isArchived ? 1 : 0,
      });
    } on Object {
      conversation.isArchived = previous;
      rethrow;
    } finally {
      _conversationChanged();
    }
  }

  Future<void> toggleConversationPin([String? id]) async {
    final conversation = await _targetConversation(id);
    final previous = conversation.isPinned;
    conversation.isPinned = !previous;
    try {
      await _saveConversationHeader(conversation, {
        'pinned': conversation.isPinned ? 1 : 0,
      });
    } on Object {
      conversation.isPinned = previous;
      rethrow;
    } finally {
      _conversationChanged();
    }
  }

  Future<void> renameConversation(String id, String title) async {
    final name = title.trim();
    if (name.isEmpty) throw ArgumentError('请输入会话名称');
    final conversation = await _targetConversation(id);
    final previous = conversation.storedTitle;
    if (previous == name) return;
    if (conversation.kind == ConversationKind.group) {
      final notice = AgentMessage(
        id: newMessageId(),
        role: AgentMessageRole.user,
        senderId: MessageSender.localUser.id,
        isSystem: true,
        text:
            '${memory.nickname.isEmpty ? MessageSender.localUser.name : memory.nickname}将群名改为“$name”',
        createdAt: DateTime.now(),
      );
      await _store.writer.flush();
      await _store.database.transaction((txn) async {
        await txn.update(
          'conversations',
          {
            'title': name,
            'updated_at': notice.createdAt.microsecondsSinceEpoch,
            'preview': notice.text,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
        await txn.insert('messages', messageRow(id, notice));
        await txn.rawUpdate(
          'UPDATE conversations SET message_count = message_count + 1 WHERE id = ?',
          [id],
        );
      });
      _syncConversationMetadata(conversation, {'title': name});
      conversation.messages.add(notice);
      conversation.messageCount++;
      conversation.storedPreview = notice.text;
      conversation.storedPreviewIsSystem = true;
      _store.writer.remember([notice]);
      _updateConversationList(conversation);
      _conversationChanged();
      await _receiveGroupSystemNotice(id, notice);
      return;
    }
    conversation.storedTitle = name;
    try {
      await _saveConversationHeader(conversation, {'title': name});
    } on Object {
      conversation.storedTitle = previous;
      rethrow;
    } finally {
      _conversationChanged();
    }
  }

  Future<void> _saveConversationHeader(
    Conversation conversation,
    Map<String, Object?> values,
  ) async {
    await _store.writer.updateMetadata(conversation, values);
    _syncConversationMetadata(conversation, values);
    if (conversation.id == activeConversation.id) {
      _updateConversationList();
    } else {
      final membership = await _store.database.query(
        'conversation_members',
        columns: ['sender_id'],
        where: 'conversation_id = ? AND sender_id = ? AND left_at IS NULL',
        whereArgs: [conversation.id, MessageSender.localUser.id],
        limit: 1,
      );
      if (membership.isNotEmpty) _updateConversationList(conversation);
    }
  }

  void _syncConversationMetadata(
    Conversation source,
    Map<String, Object?> values,
  ) {
    final copies = <Conversation>{
      source,
      _viewConversation,
      ..._conversations,
      for (final state in _executionStates.values)
        if (state.conversation != null) state.conversation!,
    }.where((conversation) => conversation.id == source.id);
    for (final copy in copies) {
      if (values.containsKey('title'))
        copy.storedTitle = values['title'] as String;
      if (values.containsKey('pinned')) copy.isPinned = values['pinned'] == 1;
      if (values.containsKey('archived'))
        copy.isArchived = values['archived'] == 1;
      if (values.containsKey('mode'))
        copy.mode = ConversationMode.values.byName(values['mode'] as String);
    }
  }

  Future<void> deleteConversation([String? id]) async {
    final removed = await _targetConversation(id);
    final isActive = removed.id == activeConversation.id;
    if (_liveConversation(removed.id) != null ||
        changingConversation ||
        (isActive && (isBusy || addingImages))) {
      throw StateError('请等待当前操作完成，再删除会话');
    }
    await toolApprovals.removeConversation(removed.id);
    final images = await _store.attachmentPaths(removed.id);
    if (isActive) {
      final replacement = _newConversation;
      await _store.delete(removed, replacement);
      _activeConversation = replacement;
      _activeAi = await groupStore.loadAi(replacement.defaultSenderId);
      _store.writer.retain([
        ...replacement.messages,
        if (_runningConversation != null && _runningConversation != replacement)
          ..._runningConversation!.messages,
      ]);
    } else {
      await _store.writer.flush();
      await _store.database.transaction((txn) async {
        await txn.delete(
          'conversations',
          where: 'id = ?',
          whereArgs: [removed.id],
        );
        await txn.delete(
          'app_state',
          where: 'key IN (?, ?, ?, ?)',
          whereArgs: [
            'context_summary:${removed.id}',
            'seen_run:${removed.id}',
            'group_read:${removed.id}',
            'pending_message_queue:${removed.id}',
          ],
        );
      });
    }
    _pendingMessageQueues.remove(removed.id);
    _conversations.removeWhere((conversation) => conversation.id == removed.id);
    _updateConversationList();
    _conversationChanged();
    for (final path in images) {
      await File(path).delete();
    }
  }
}
