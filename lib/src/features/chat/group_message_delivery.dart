part of 'chat_controller.dart';

/// This is the publication boundary: model text remains private until this call.
extension GroupMessageDelivery on ChatController {
  Future<Map<String, Object?>> _deliverGroupMessages({
    required Map<String, Object?> arguments,
    required Conversation member,
    required Conversation parent,
    required _ReplyContext reply,
    required List<AgentMessage> observed,
    required List<String> publishedIds,
  }) async {
    final groupId = arguments['groupId'] as String?;
    if (groupId != null && groupId != parent.id) {
      throw ArgumentError('群内只能向当前群发送消息');
    }
    _checkGroupStopped(parent);
    if (_removedGroupMembers.contains(reply.senderId) ||
        member.runState == ChatRunState.stopping) {
      throw const AgentCancelled();
    }
    final dispatcher = _groupDispatcher!;
    final seen = {for (final m in observed) m.id: m};
    final fresh = dispatcher.history
        .where(
          (m) => !seen.containsKey(m.id) || seen[m.id]!.isSystem != m.isSystem,
        )
        .toList();
    dispatcher.acknowledge(reply.senderId);
    if (fresh.isNotEmpty) {
      observed.removeWhere((m) => fresh.any((f) => f.id == m.id));
      observed.addAll(fresh);
      return {
        'sent': false,
        'reason': 'new_messages',
        '_images': fresh.expand((m) => m.images).toList(),
        'messages': [
          for (final message in fresh)
            {
              'id': message.id,
              'senderId': message.senderId,
              'kind': message.isSystem ? 'system_event' : 'message',
              'name': message.sender?.name ?? MessageSender.localUser.name,
              'text': _quotedInput(message),
              'files': message.files.map((f) => f.toJson()).toList(),
            },
        ],
        'instruction': '先阅读新消息，再决定原样发送、修改草稿或保持沉默；不要重复已经执行的操作。',
      };
    }
    final senders = _groupSenders;
    if (!senders.containsKey(reply.senderId)) throw const AgentCancelled();
    final byId = {for (final m in dispatcher.history) m.id: m};
    final mentions = <String>{};
    final output = <AgentMessage>[];
    for (final raw in arguments['messages'] as List) {
      final item = (raw as Map).cast<String, Object?>();
      final text = (item['text'] as String).trim();
      final images = item['_images'] as List<MessageImage>;
      if (text.isEmpty && images.isEmpty) throw ArgumentError('消息不能为空');
      final ids = List<String>.from(item['mentionIds'] as List);
      if (ids.any((id) => !senders.containsKey(id))) {
        throw ArgumentError('只能 @ 当前群成员');
      }
      final quoteId = item['quoteMessageId'] as String?;
      final source = quoteId == null ? null : byId[quoteId];
      if (quoteId != null && source == null) {
        throw ArgumentError('引用消息必须来自当前群聊');
      }
      final quote = source == null
          ? null
          : (MessageQuote(
                messageId: source.id,
                senderId: source.senderId,
                text: source.text,
              )
              ..senderName =
                  source.sender?.name ?? MessageSender.localUser.name);
      mentions.addAll(ids);
      output.add(
        AgentMessage(
          id: newMessageId(),
          role: AgentMessageRole.assistant,
          isGroupMessage: true,
          senderId: reply.senderId,
          sender: _groupSenders[reply.senderId]!,
          runId: member.activeRunId,
          text: [
            if (ids.isNotEmpty)
              ids
                  .map((id) {
                    final name = senders[id]!.name
                        .replaceAll('[', r'\[')
                        .replaceAll(']', r'\]');
                    return '[@$name](aurai://member/${Uri.encodeComponent(id)})';
                  })
                  .join(' '),
            text,
          ].join(' '),
          quote: quote,
          images: images,
          createdAt: DateTime.now(),
        ),
      );
    }
    final participation = arguments['participation'] as String;
    if (participation != 'unchanged') {
      // Only human messages in this context may authorize a participation change.
      await GroupParticipation(
        _store.database,
      ).set(parent.id, reply.senderId, participation == 'paused');
      if (participation == 'paused') {
        dispatcher.pause(reply.senderId);
      } else {
        dispatcher.paused.remove(reply.senderId);
      }
    }
    _checkGroupStopped(parent);
    // Reconsider after asynchronous state persistence, before changing messages.
    if (dispatcher.history.length != observed.length ||
        dispatcher.history.any(
          (m) => observed.any(
            (old) => old.id == m.id && old.isSystem != m.isSystem,
          ),
        )) {
      return _deliverGroupMessages(
        arguments: {...arguments, 'participation': 'unchanged'},
        member: member,
        parent: parent,
        reply: reply,
        observed: observed,
        publishedIds: publishedIds,
      );
    }
    if (_removedGroupMembers.contains(reply.senderId) ||
        member.runState == ChatRunState.stopping) {
      throw const AgentCancelled();
    }
    member.messages.addAll(output);
    member.messageCount += output.length;
    try {
      await _persistMember(member, parent);
    } on Object {
      final ids = output.map((m) => m.id).toSet();
      member.messages.removeWhere((m) => ids.contains(m.id));
      member.messageCount -= output.length;
      parent.messages.removeWhere((m) => ids.contains(m.id));
      parent.messageCount -= output.length;
      rethrow;
    }
    publishedIds.addAll(output.map((m) => m.id));
    observed.addAll(output);
    if (output.isNotEmpty) dispatcher.receive(output, mentions: mentions);
    _notifyMember(member, parent);
    return {
      'sent': true,
      'messageIds': output.map((m) => m.id).toList(),
      'participation': dispatcher.paused.contains(reply.senderId)
          ? 'paused'
          : 'active',
      'instruction': '这些消息已发送，不要再重复。没有新的内容就结束本次执行。',
    };
  }

  Future<Map<String, Object?>> _changePrivateGroupParticipation(
    Map<String, Object?> arguments,
    String senderId,
  ) async {
    final groupId = arguments['groupId'] as String?;
    if (groupId == null) throw ArgumentError('请先确认要调整哪个群聊');
    if ((arguments['messages'] as List).isNotEmpty) {
      throw ArgumentError('私聊中此工具仅调整接话状态，不能发送群消息');
    }
    final participation = arguments['participation'] as String;
    if (!['paused', 'active'].contains(participation)) {
      throw ArgumentError('请选择暂停或恢复接话');
    }
    final roster = await groupStore.members(groupId);
    if (!roster.any((m) => m.sender.id == senderId)) {
      throw ArgumentError('你不是这个群的成员');
    }
    final paused = participation == 'paused';
    await GroupParticipation(_store.database).set(groupId, senderId, paused);
    if (_runningConversation?.id == groupId) {
      if (paused) {
        _groupDispatcher?.pause(senderId);
        await _groupRuntimes[senderId]?.cancel();
      } else {
        _groupDispatcher?.paused.remove(senderId);
      }
    }
    return {'participation': participation, 'groupId': groupId};
  }
}
