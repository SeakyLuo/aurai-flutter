part of 'chat_controller.dart';

extension PrivateGroupMessage on ChatController {
  Future<Map<String, Object?>> _sendPrivateGroupMessage(
    Map<String, Object?> arguments,
    String senderId, {
    bool requireGroup = true,
    String? sourceId,
  }) async {
    final id = arguments['groupId'] as String?;
    if (id == null) throw ArgumentError('私聊发送群消息需要先用 listGroupChats 确认目标群');
    final rows = await _store.database.query(
      'conversations',
      columns: ['id', 'kind'],
      where: requireGroup ? "id = ? AND kind = 'group'" : 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw ArgumentError('目标会话不存在');
    final isGroup = rows.single['kind'] == 'group';
    final roster = await groupStore.members(id);
    final senders = {
      for (final member in roster) member.sender.id: member.sender,
    };
    if (!senders.containsKey(senderId)) throw ArgumentError('你不是这个会话的成员');
    final item = arguments['message'] as Map<String, Object?>?;
    final participation = arguments['participation'] as String;
    if (item == null) {
      if (participation == 'unchanged')
        return {'sent': false, 'participation': participation, 'groupId': id};
      return _changePrivateGroupParticipation(arguments, senderId);
    }
    final images = item['_images'] as List<MessageImage>;
    final text = (item['text'] as String).trim();
    if (text.length > 20000) throw ArgumentError('消息文字不能超过 20000 字');
    final mentions = List<String>.from(item['mentionIds'] as List).toSet();
    if (!isGroup && mentions.isNotEmpty) throw ArgumentError('私聊无需 @ 成员');
    if (mentions.any((id) => !senders.containsKey(id)))
      throw ArgumentError('只能 @ 当前群成员');
    final quoteId = item['quoteMessageId'] as String?;
    MessageQuote? quote;
    if (quoteId != null) {
      final sources = await _store.database.query(
        'messages',
        columns: ['id', 'sender_id', 'text'],
        where: 'id = ? AND conversation_id = ?',
        whereArgs: [quoteId, id],
        limit: 1,
      );
      if (sources.isEmpty) throw ArgumentError('引用消息必须来自目标会话');
      final source = sources.single;
      quote = MessageQuote(
        messageId: quoteId,
        senderId: source['sender_id'] as String,
        text: source['text'] as String,
      );
      final authors = await _store.database.query(
        'message_senders',
        columns: ['name'],
        where: 'id = ?',
        whereArgs: [quote.senderId],
        limit: 1,
      );
      quote.senderName = authors.single['name'] as String;
    }
    final inlineMentions = RegExp(
      r'\]\(aurai://member/([^)]+)\)',
    ).allMatches(text).map((match) => match.group(1)!).toSet();
    final prefixes = mentions
        .where(
          (id) =>
              !inlineMentions.contains(Uri.encodeComponent(id)) &&
              !RegExp(
                '@${RegExp.escape(senders[id]!.name)}(?![a-zA-Z0-9_])',
              ).hasMatch(text),
        )
        .map((id) {
          final name = senders[id]!.name
              .replaceAll('[', r'\[')
              .replaceAll(']', r'\]');
          return '[@$name](aurai://member/${Uri.encodeComponent(id)})';
        });
    if (!isGroup &&
        roster.every((m) => m.sender.kind == MessageSenderKind.agent)) {
      return _sendPeerMessage(id, senderId, text, images: images, quote: quote);
    }
    final target = await _forwardTarget(id);
    final inlineRunId = !isGroup && sourceId == id
        ? _runningConversation?.activeRunId
        : null;
    final message = AgentMessage(
      id: newMessageId(),
      role: AgentMessageRole.assistant,
      senderId: senderId,
      sender: senders[senderId]!,
      isGroupMessage: isGroup,
      runId: inlineRunId,
      isRichReply: inlineRunId != null,
      text: [...prefixes, if (text.isNotEmpty) text].join(' '),
      images: images,
      quote: quote,
      createdAt: DateTime.now(),
    );
    target.messages.add(message);
    target.messageCount++;
    try {
      await _store.writer.save(
        target,
        makeActive: false,
        participation: participation == 'unchanged'
            ? null
            : (senderId: senderId, paused: participation == 'paused'),
      );
    } on Object {
      target.messages.remove(message);
      target.messageCount--;
      rethrow;
    }
    if (participation != 'unchanged')
      await _applyPrivateGroupParticipation(
        id,
        senderId,
        participation == 'paused',
      );
    _updateConversationList(target);
    _conversationChanged();
    // Persistence is the send boundary; dispatch failures must not cause the tool
    // to delete delivered images or tell the AI to send the same message again.
    if (isGroup) {
      unawaited(
        _receiveGroupSystemNotice(id, message).catchError((Object error) {
          debugPrint('Private group message dispatch failed: $error');
        }),
      );
    }
    return {
      'sent': true,
      'messageId': message.id,
      'groupId': id,
      'conversationId': id,
      'participation': participation,
    };
  }
}
