part of 'chat_controller.dart';

extension ImageForwarding on ChatController {
  Future<T> _enqueueForward<T>(Future<T> Function() action) {
    final next = _forwardingTail.then((_) => action());
    _forwardingTail = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return next;
  }

  Future<List<Conversation>> imageForwardTargets(
    String query,
    int offset,
  ) async {
    final rows = await _store.database.query(
      'conversations',
      where: "archived = 0 AND instr(lower(title), ?) > 0",
      whereArgs: [query.toLowerCase()],
      orderBy: 'updated_at DESC, id DESC',
      limit: 30,
      offset: offset,
    );
    return rows.map(conversationFromRow).toList();
  }

  Future<({String conversationId, String messageId})?> imageOrigin({
    String? messageId,
    String? path,
  }) async {
    final rows = messageId != null
        ? await _store.database.query(
            'messages',
            columns: ['conversation_id', 'id'],
            where: 'id = ?',
            whereArgs: [messageId],
            limit: 1,
          )
        : await _store.database.query(
            'attachments',
            columns: ['conversation_id', 'message_id'],
            where: 'file_name = ? AND message_id IS NOT NULL',
            whereArgs: [File(path!).uri.pathSegments.last],
            limit: 1,
          );
    if (rows.isEmpty) return null;
    return (
      conversationId: rows.single['conversation_id'] as String,
      messageId: rows.single[messageId != null ? 'id' : 'message_id'] as String,
    );
  }

  Future<void> forwardImage(String? targetId, List<int> bytes, String text) =>
      _inConversation(
        activeConversation,
        () => _enqueueForward(() => _forwardImage(targetId, bytes, text)),
      );

  Future<void> _forwardImage(
    String? targetId,
    List<int> bytes,
    String text,
  ) async {
    MessageImage? image;
    var saved = false;
    try {
      var target = targetId == null
          ? Conversation.empty()
          : await _forwardTarget(targetId);
      image = await _imageStore.importBytes(bytes);
      final message = AgentMessage(
        id: newMessageId(),
        role: AgentMessageRole.user,
        senderId: MessageSender.localUser.id,
        text: text,
        images: [image],
        createdAt: DateTime.now(),
      );
      target =
          _liveConversation(target.id) ??
          (target.id == _viewConversation.id ? _viewConversation : target);
      await _saveForwardedMessage(
        target,
        message,
        target.kind == ConversationKind.group
            ? [target.defaultSenderId]
            : const [],
      );
      saved = true;
    } finally {
      if (!saved && image != null) await _imageStore.remove([image]);
      _conversationChanged();
    }
  }

  Future<String> forwardMessage(
    String? targetId,
    AgentMessage source,
    String note,
  ) => _inConversation(
    activeConversation,
    () => _enqueueForward(() => _forwardMessage(targetId, source, note)),
  );

  Future<String> _forwardMessage(
    String? targetId,
    AgentMessage source,
    String note,
  ) async {
    final copies = <File>[];
    var saved = false;
    try {
      var target = targetId == null
          ? Conversation.empty()
          : await _forwardTarget(targetId);
      final images = <MessageImage>[];
      final files = <MessageFile>[];
      Future<String> copy(String path) async {
        final original = File(path);
        if (!await original.exists()) throw StateError('原消息的附件已丢失，请重新添加后发送');
        final destination = File(
          '${_imageStore.directory}/${newMessageId()}_${original.uri.pathSegments.last}',
        );
        copies.add(destination);
        await original.copy(destination.path);
        return destination.path;
      }

      for (final image in source.images) {
        images.add(
          MessageImage(
            path: await copy(image.path),
            mimeType: image.mimeType,
            name: image.name,
          ),
        );
      }
      for (final file in source.files) {
        files.add(
          MessageFile(
            path: await copy(file.path),
            name: file.name,
            mimeType: file.mimeType,
            size: file.size,
          ),
        );
      }
      if (source.htmlGame != null) {
        final rows = await _store.database.query(
          'html_games',
          columns: ['title', 'conversation_id'],
          where:
              'message_id = ? AND message_id IN (SELECT id FROM messages WHERE kind = ?)',
          whereArgs: [source.id, 'html_game'],
          limit: 1,
        );
        if (rows.isEmpty) throw StateError('原 HTML 消息已删除或撤回，无法转发');
        final document = rows.single;
        final application = await htmlGames.load(
          document['conversation_id'] as String,
          source.id,
        );
        final bytes = utf8.encode(application.html);
        final file = File('${_imageStore.directory}/${newMessageId()}.html');
        copies.add(file);
        await file.writeAsBytes(bytes);
        files.add(
          MessageFile(
            path: file.path,
            name: '${document['title']}.html',
            mimeType: 'text/html',
            size: bytes.length,
          ),
        );
      }
      final recipients = target.kind == ConversationKind.group
          ? (await groupStore.members(target.id))
                .where((m) => m.sender.kind == MessageSenderKind.agent)
                .map((m) => m.sender.id)
                .toList()
          : const <String>[];
      final message = AgentMessage(
        id: newMessageId(),
        role: AgentMessageRole.user,
        senderId: MessageSender.localUser.id,
        text: [
          if (source.htmlGame == null && source.interactive == null)
            source.text,
          if (note.isNotEmpty) note,
        ].where((part) => part.isNotEmpty).join('\n\n'),
        images: images,
        files: files,
        interactive: source.interactive?.forwardedFor(
          MessageSender.localUser.id,
        ),
        createdAt: DateTime.now(),
      );
      target =
          _liveConversation(target.id) ??
          (target.id == _viewConversation.id ? _viewConversation : target);
      await _saveForwardedMessage(
        target,
        message,
        target.kind == ConversationKind.group ? recipients : const [],
      );
      saved = true;
      return message.id;
    } finally {
      if (!saved) {
        for (final file in copies) {
          if (await file.exists()) await file.delete();
        }
      }
      _conversationChanged();
    }
  }

  Future<void> _saveForwardedMessage(
    Conversation target,
    AgentMessage message,
    List<String> recipients,
  ) => _inConversation(target, () async {
    final previousPending = target.pendingGoal;
    final previousQueued = _execution.queuedUserMessageId;
    _execution.forwardingMessage = true;
    if (target.kind == ConversationKind.direct) {
      target.pendingGoal = message.text;
      _execution.queuedUserMessageId = message.id;
    }
    target.messages.add(message);
    target.messageCount++;
    try {
      await _store.writer.save(
        target,
        makeActive: false,
        recipients: target.kind == ConversationKind.group
            ? {message.id: recipients}
            : const {},
      );
    } on Object {
      if (_execution.queuedUserMessageId == message.id) {
        target.pendingGoal = previousPending;
        _execution.queuedUserMessageId = previousQueued;
      }
      target.messages.removeWhere((item) => item.id == message.id);
      target.messageCount--;
      rethrow;
    } finally {
      _execution.forwardingMessage = false;
    }
    _updateConversationList(target);
    unawaited(_deliverForwardedMessage(target, message));
  });

  Future<Conversation> _forwardTarget(String id) async {
    final live = _liveConversation(id);
    if (live != null) return live;
    if (id == _viewConversation.id) return _viewConversation;
    final loaded = await _store.load(id);
    return _liveConversation(id) ??
        (id == _viewConversation.id ? _viewConversation : loaded);
  }

  Future<void> _deliverForwardedMessage(
    Conversation target,
    AgentMessage message,
  ) => _inConversation(target, () async {
    try {
      if (target.kind == ConversationKind.group && _groupDispatcher != null) {
        await _receiveGroupSystemNotice(target.id, message);
        return;
      }
      // Only successive messages in the same conversation share a reply turn.
      if (_runningConversation != null ||
          _privateConversation != null ||
          _submitting ||
          _systemEventLoading) {
        if (target.kind == ConversationKind.group)
          _execution.forwardedReplyPending = true;
        return;
      }
      await _runForwardedImage(target);
    } on Object catch (error, stack) {
      developer.log(
        'Forwarded message dispatch failed',
        error: error,
        stackTrace: stack,
      );
    }
  });

  void _resumeForwardedReply() {
    if (_callbacksDisposed ||
        _runningConversation != null ||
        _privateConversation != null ||
        _submitting ||
        _execution.forwardingMessage ||
        _systemEventLoading)
      return;
    if (!_execution.forwardedReplyPending &&
        _execution.queuedUserMessageId == null)
      return;
    _execution.forwardedReplyPending = false;
    final target = _execution.conversation!;
    unawaited(_inConversation(target, () => _runForwardedImage(target)));
  }

  Future<void> _runForwardedImage(Conversation target) async {
    final queuedAtStart = _execution.queuedUserMessageId;
    target.executionUserMessageId = null;
    _runningConversation = target;
    _conversationChanged();
    try {
      if (target.kind == ConversationKind.direct &&
          !(await _directReplyContext(target)).config.isConfigured) {
        if (_execution.queuedUserMessageId == queuedAtStart)
          _execution.queuedUserMessageId = null;
        target.runState = ChatRunState.idle;
        await _persistRun(target);
        return;
      }
      await _executeConversation(target);
    } on Object catch (error) {
      if (target.executionUserMessageId == null &&
          _execution.queuedUserMessageId == queuedAtStart)
        _execution.queuedUserMessageId = null;
      target.runState = ChatRunState.failed;
      target.errorDetail = error.toString();
      await _persistRun(target);
    } finally {
      _runningConversation = null;
      _resumeForwardedReply();
      _updateConversationList(target);
      _conversationChanged();
    }
  }
}
