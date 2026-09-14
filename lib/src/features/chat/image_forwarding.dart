part of 'chat_controller.dart';

extension ImageForwarding on ChatController {
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

  Future<void> forwardImage(
    String? targetId,
    List<int> bytes,
    String text,
  ) async {
    if (hasRunningTask) throw StateError('另一个会话正在运行，请等待完成后再发送');
    _submitting = true;
    MessageImage? image;
    var saved = false;
    try {
      final target = targetId == null
          ? Conversation.empty()
          : targetId == activeConversation.id
          ? activeConversation
          : await _store.load(targetId);
      if (target.kind == ConversationKind.direct &&
          !(await _directReplyContext(target)).config.isConfigured)
        throw StateError('请先配置目标 AI 的模型');
      image = await _imageStore.importBytes(bytes);
      final message = AgentMessage(
        id: newMessageId(),
        role: AgentMessageRole.user,
        senderId: MessageSender.localUser.id,
        text: text,
        images: [image],
        createdAt: DateTime.now(),
      );
      target.messages.add(message);
      target.messageCount++;
      try {
        await _store.writer.save(
          target,
          makeActive: false,
          recipients: target.kind == ConversationKind.group
              ? {
                  message.id: [target.defaultSenderId],
                }
              : const {},
        );
      } on Object {
        target.messages.remove(message);
        target.messageCount--;
        rethrow;
      }
      saved = true;
      _runningConversation = target;
      _updateConversationList(target);
      unawaited(_runForwardedImage(target));
    } finally {
      _submitting = false;
      if (!saved && image != null) await _imageStore.remove([image]);
      _conversationChanged();
    }
  }

  Future<void> forwardMessage(
    String? targetId,
    AgentMessage source,
    String note,
  ) async {
    if (hasRunningTask || _submitting) throw StateError('另一个会话正在运行，请等待完成后再发送');
    _submitting = true;
    final copies = <File>[];
    var saved = false;
    try {
      final target = targetId == null
          ? Conversation.empty()
          : targetId == activeConversation.id
          ? activeConversation
          : await _store.load(targetId);
      if (target.kind == ConversationKind.direct &&
          !(await _directReplyContext(target)).config.isConfigured) {
        throw StateError('请先配置目标 AI 的模型');
      }
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
          source.text,
          if (note.isNotEmpty) note,
        ].where((part) => part.isNotEmpty).join('\n\n'),
        images: images,
        files: files,
        createdAt: DateTime.now(),
      );
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
        target.messages.remove(message);
        target.messageCount--;
        rethrow;
      }
      saved = true;
      _runningConversation = target;
      _updateConversationList(target);
      unawaited(_runForwardedImage(target));
    } finally {
      _submitting = false;
      if (!saved) {
        for (final file in copies) {
          if (await file.exists()) await file.delete();
        }
      }
      _conversationChanged();
    }
  }

  Future<void> _runForwardedImage(Conversation target) async {
    try {
      await _executeConversation(target);
    } on Object catch (error) {
      target.runState = ChatRunState.failed;
      target.errorDetail = error.toString();
      await _persistRun(target);
    } finally {
      _runningConversation = null;
      _updateConversationList(target);
      _conversationChanged();
    }
  }
}
