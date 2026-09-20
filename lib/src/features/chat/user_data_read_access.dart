part of 'chat_controller.dart';

extension UserDataReadAccess on ChatController {
  AgentTool _withUserDataReadAccess(
    AgentTool tool,
    Conversation conversation,
    String senderId,
    String? groupId,
  ) {
    final name = tool.definition.name;
    if (!const {
      'readGroupChat',
      'readGroupMessages',
      'readMessage',
      'readMessageAttachment',
      'readAttachment',
      'readInteractiveMessage',
      'readHtmlMessage',
    }.contains(name))
      return tool;
    final user = MessageSender.localUser.id;
    final AgentTool delegated = switch (name) {
      'readGroupChat' => GroupChatTool(
        groupStore,
        'read',
        conversation.id,
        (tool as GroupChatTool).rename,
        tool.updateMembers,
        tool.changed,
        senderId: user,
      ),
      'readGroupMessages' => ReadGroupMessagesTool(
        groupStore,
        senderId: user,
        currentGroupId: groupId,
      ),
      'readInteractiveMessage' => InteractiveMessageTool(
        name,
        (operation, args) =>
            _interactiveMessage(operation, args, conversation, user),
      ),
      'readHtmlMessage' => HtmlMessageUpdateTool(name, (operation, args) async {
        await _store.writer.flush();
        final target = await _messageConversation(
          args['messageId'] as String,
          user,
          conversation,
        );
        return htmlGames.updateMessage(operation, target.id, user, args);
      }),
      _ => HistoryMessageTool(
        _store.database,
        _store.reader.imageDirectory,
        senderId: user,
        name: name,
        inGroup: false,
      ),
    };
    return UserDataReadTool(
      original: tool,
      delegated: delegated,
      resolve: (call) => _resolveDataReadAccess(call, senderId, groupId),
    );
  }

  Future<({bool useUserScope, String title})> _resolveDataReadAccess(
    ToolCall call,
    String senderId,
    String? groupId,
  ) async {
    final args = call.arguments;
    final isGroup =
        call.name == 'readGroupMessages' || call.name == 'readGroupChat';
    if (call.name == 'readGroupChat' && !args.containsKey('id')) {
      return (useUserScope: false, title: '');
    }
    final String? id = isGroup
        ? (args[call.name == 'readGroupChat' ? 'id' : 'groupId'] as String? ??
              groupId)
        : call.name == 'readAttachment'
        ? args['attachmentId'] as String?
        : args['messageId'] as String?;
    if (id == null) return (useUserScope: false, title: '');
    final db = _store.database;
    final targets = isGroup
        ? await db.query(
            'conversations',
            columns: ['id', 'title'],
            where: "id = ? AND kind = 'group'",
            whereArgs: [id],
            limit: 1,
          )
        : await db.query(
            'messages',
            columns: ['conversation_id', 'interactive_json', 'kind'],
            where: call.name == 'readAttachment'
                ? 'id IN (SELECT message_id FROM attachments WHERE id = ?)'
                : 'id = ?',
            whereArgs: [id],
            limit: 1,
          );
    if (targets.isEmpty) return (useUserScope: false, title: '');
    final target = targets.single;
    final conversationId = isGroup ? target['id'] : target['conversation_id'];
    final memberships = await db.query(
      'conversation_members',
      columns: ['sender_id'],
      where: 'conversation_id = ? AND sender_id IN (?, ?) AND left_at IS NULL',
      whereArgs: [conversationId, senderId, MessageSender.localUser.id],
      limit: 2,
    );
    final members = memberships.map((r) => r['sender_id']).toSet();
    final card = !isGroup && target['interactive_json'] != null
        ? InteractiveMessage.fromJson(
            jsonDecode(target['interactive_json'] as String)
                as Map<String, dynamic>,
          )
        : null;
    bool canRead(String actor) {
      if (!members.contains(actor) || (card != null && !card.canView(actor))) {
        return false;
      }
      final participant = args['participantId'];
      if (call.name == 'readInteractiveMessage' &&
          card != null &&
          participant != null &&
          participant != actor) {
        return card.visible('visibility', actor: actor) &&
            card.visible('summaryVisibility', actor: actor);
      }
      return true;
    }

    if (canRead(senderId) || !canRead(MessageSender.localUser.id)) {
      return (useUserScope: false, title: '');
    }
    final titles = isGroup
        ? targets
        : await db.query(
            'conversations',
            columns: ['title'],
            where: 'id = ?',
            whereArgs: [conversationId],
            limit: 1,
          );
    return (
      useUserScope: true,
      title: titles.single['title'] as String? ?? '会话',
    );
  }
}
