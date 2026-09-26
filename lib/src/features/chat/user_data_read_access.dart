part of 'chat_controller.dart';

extension UserDataReadAccess on ChatController {
  AgentTool _withUserDataReadAccess(
    AgentTool tool,
    Conversation conversation,
    String senderId,
    String? groupId,
  ) {
    final name = tool.definition.name;
    if (tool is GroupMessageMarksTool || tool is GroupAnnouncementTool) {
      final user = MessageSender.localUser.id;
      final AgentTool delegated = tool is GroupMessageMarksTool
          ? GroupMessageMarksTool(
              GroupMessageMarks(
                groupStore,
                actorId: senderId,
                accessActorId: user,
              ),
              name,
              tool.currentGroupId,
              () => _store.writer.flush(),
            )
          : GroupAnnouncementTool(
              GroupAnnouncementStore(groupStore),
              senderId,
              groupId ?? conversation.id,
              write: (tool as GroupAnnouncementTool).write,
              accessActorId: user,
            );
      return GroupAccessTool(
        original: tool,
        delegated: delegated,
        resolve: (call) => _resolveGroupAccess(
          call,
          senderId,
          groupId ??
              (conversation.kind == ConversationKind.group
                  ? conversation.id
                  : null),
        ),
      );
    }
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
        return htmlStore.updateMessage(operation, target.id, user, args);
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

  Future<({bool useUserScope, String title, String preview})>
  _resolveGroupAccess(ToolCall call, String senderId, String? groupId) async {
    final scope = await _resolveDataReadAccess(call, senderId, groupId);
    var preview = '';
    final messageId = call.arguments['messageId'] as String?;
    if (scope.useUserScope && messageId != null) {
      final (rows, attachments, apps) = await (
        _store.database.query(
          'messages',
          columns: ['text', 'interactive_json'],
          where: 'id = ? AND conversation_id = ?',
          whereArgs: [
            messageId,
            call.arguments['groupId'] as String? ?? groupId,
          ],
        ),
        _store.database.query(
          'attachments',
          columns: ['kind', 'display_name'],
          where: 'message_id = ?',
          whereArgs: [messageId],
          orderBy: 'position',
          limit: 3,
        ),
        _store.database.query(
          'html_games',
          columns: ['title'],
          where: 'message_id = ?',
          whereArgs: [messageId],
        ),
      ).wait;
      if (rows.isNotEmpty) {
        final raw = rows.single['interactive_json'] as String?;
        if (raw == null) {
          preview = [
            rows.single['text'] as String,
            if (apps.isNotEmpty) '[小程序] ${apps.single['title']}',
            for (final attachment in attachments)
              attachment['kind'] == 'image'
                  ? '[图片]'
                  : '[文件] ${attachment['display_name']}',
          ].where((text) => text.isNotEmpty).join(' ');
        } else {
          final card = InteractiveMessage.fromJson(
            jsonDecode(raw) as Map<String, dynamic>,
          );
          card.requireViewer(MessageSender.localUser.id);
          final view = card.viewFor(MessageSender.localUser.id);
          preview = '${view.title}\n${view.body}';
        }
      }
    }
    return (
      useUserScope: scope.useUserScope,
      title: scope.title,
      preview: preview,
    );
  }

  Future<({bool useUserScope, String title})> _resolveDataReadAccess(
    ToolCall call,
    String senderId,
    String? groupId,
  ) async {
    final args = call.arguments;
    final isGroup =
        call.name == 'readGroupMessages' ||
        call.name == 'readGroupChat' ||
        call.name == 'readGroupAnnouncement' ||
        call.name == 'updateGroupAnnouncement' ||
        GroupMessageMarksTool.names.contains(call.name);
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
