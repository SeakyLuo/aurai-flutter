part of 'chat_controller.dart';

extension AppControlActions on ChatController {
  Future<Map<String, Object?>> _controlApp(
    String operation,
    Map<String, Object?> args,
    String senderId,
    String sourceId,
  ) async {
    if (operation == 'createConversation') {
      final title = (args['title'] as String).trim();
      if (title.isEmpty || title.length > 100)
        throw ArgumentError('会话名称需为 1–100 字');
      final contactId = args['contactId'] as String?;
      if (contactId != null) {
        final id = await ContactRelationships(
          _store.database,
        ).create(senderId, contactId, title);
        _conversationChanged();
        return {'conversationId': id, 'title': title};
      }
      final value = Conversation.empty()
        ..defaultSenderId = senderId
        ..storedTitle = title;
      await _store.database.insert('conversations', conversationRow(value));
      _conversationChanged();
      return {
        'conversationId': value.id,
        'title': value.title,
        'created': true,
      };
    }
    if (operation == 'openAppPage' && args['page'] != 'conversation') {
      if (args['page'] == 'contact') {
        final id = args['contactId'];
        if (id is! String) throw ArgumentError('请先查找联系人');
        await groupStore.loadAi(id);
      }
      final navigate = openAppPage;
      if (navigate == null) throw StateError('当前无法打开页面');
      await navigate({...args, 'senderId': senderId});
      return {'opened': true, 'page': args['page']};
    }
    final id = args['conversationId'];
    if (id is! String) throw ArgumentError('请先查找目标会话');
    final rows = await _store.database.query(
      'conversations',
      columns: ['id', 'kind'],
      where:
          "id = ? AND id IN (SELECT conversation_id FROM conversation_members WHERE sender_id = ? AND left_at IS NULL)",
      whereArgs: [id, senderId],
      limit: 1,
    );
    if (rows.isEmpty) throw ArgumentError('会话不存在或你无权访问');
    switch (operation) {
      case 'renameConversation':
        final title = (args['title'] as String).trim();
        if (title.isEmpty || title.length > 100)
          throw ArgumentError('会话名称需为 1–100 字');
        await renameConversation(id, title);
      case 'setConversationPinned':
        final target = await _targetConversation(id);
        if (target.isPinned != args['pinned'] as bool)
          await toggleConversationPin(id);
      case 'setConversationArchived':
        await setConversationArchived(id, archived: args['archived'] as bool);
      case 'deleteConversation':
        if (id == sourceId) throw StateError('不能删除正在执行此操作的会话');
        if (_peerSessions.containsKey(id)) throw StateError('请等目标私聊结束后再删除');
        if (id == _privateConversation?.id) throw StateError('请等目标会话回复结束后再删除');
        await deleteConversation(id);
      case 'openAppPage':
        final human = await _store.database.query(
          'conversation_members',
          columns: ['sender_id'],
          where: 'conversation_id = ? AND sender_id = ? AND left_at IS NULL',
          whereArgs: [id, MessageSender.localUser.id],
          limit: 1,
        );
        if (human.isEmpty) throw StateError('这个会话不在用户的会话列表中');
        final navigate = openAppPage;
        if (navigate == null) throw StateError('当前无法打开页面');
        await navigate({...args, 'senderId': senderId});
      case 'sendConversationMessage':
        if (rows.single['kind'] == 'direct') {
          final members = await groupStore.members(id);
          if (members.every((m) => m.sender.kind == MessageSenderKind.agent)) {
            return _sendPeerMessage(id, senderId, args['text'] as String);
          }
        }
        final text = (args['text'] as String).trim();
        if (text.isEmpty || text.length > 20000)
          throw ArgumentError('消息需为 1–20000 字');
        final target = id == activeConversation.id
            ? activeConversation
            : id == _runningConversation?.id
            ? _runningConversation!
            : id == _privateConversation?.id
            ? _privateConversation!
            : await _store.load(id);
        if (id != sourceId &&
            target.kind == ConversationKind.direct &&
            (id == _runningConversation?.id ||
                id == _privateConversation?.id)) {
          throw StateError('目标私聊正在回复，请结束后再发送');
        }
        final profile = await groupStore.loadAi(senderId);
        final message = AgentMessage(
          id: newMessageId(),
          role: AgentMessageRole.assistant,
          senderId: senderId,
          sender: profile.sender,
          text: text,
          createdAt: DateTime.now(),
          isGroupMessage: target.kind == ConversationKind.group,
        );
        target.messages.add(message);
        target.messageCount++;
        try {
          await _store.writer.save(target, makeActive: false);
        } on Object {
          target.messages.remove(message);
          target.messageCount--;
          rethrow;
        }
        _updateConversationList(target);
        _conversationChanged();
        if (target.kind == ConversationKind.group) {
          await _receiveGroupSystemNotice(id, message);
        }
        return {'sent': true, 'messageId': message.id, 'conversationId': id};
      default:
        throw ArgumentError('不支持的操作');
    }
    return {'completed': true, 'conversationId': id};
  }
}
