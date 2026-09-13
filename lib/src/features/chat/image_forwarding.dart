part of 'chat_controller.dart';

extension ImageForwarding on ChatController {
  Future<List<({String id, String title})>> imageForwardTargets(
    String query,
    int offset,
  ) async {
    final rows = await _store.database.query(
      'conversations',
      columns: ['id', 'title'],
      where: "archived = 0 AND instr(lower(title), ?) > 0",
      whereArgs: [query.toLowerCase()],
      orderBy: 'updated_at DESC, id DESC',
      limit: 30,
      offset: offset,
    );
    return rows
        .map((row) => (id: row['id'] as String, title: row['title'] as String))
        .toList();
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
    if (needsConfiguration) throw StateError('请先在设置中配置模型');
    _submitting = true;
    MessageImage? image;
    var saved = false;
    try {
      final target = targetId == null
          ? Conversation.empty()
          : targetId == activeConversation.id
          ? activeConversation
          : await _store.load(targetId);
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
      notifyListeners();
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
      notifyListeners();
    }
  }
}
