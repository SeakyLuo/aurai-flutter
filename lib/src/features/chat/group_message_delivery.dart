part of 'chat_controller.dart';

/// This is the publication boundary: model text remains private until this call.
extension GroupMessageDelivery on ChatController {
  Future<Map<String, Object?>> _deliverGroupMessage({
    required Map<String, Object?> arguments,
    required Conversation member,
    required Conversation parent,
    required _ReplyContext reply,
    required List<AgentMessage> observed,
    required List<String> publishedIds,
  }) async {
    final groupId = arguments['groupId'] as String?;
    if (groupId != null && groupId != parent.id) {
      _checkGroupStopped(parent);
      if (_removedGroupMembers.contains(reply.senderId) ||
          member.runState == ChatRunState.stopping) {
        throw const AgentCancelled();
      }
      return _sendPrivateGroupMessage(arguments, reply.senderId);
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
    final item = arguments['message'] as Map<String, Object?>?;
    if (item != null) {
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
      final inlineMentions = RegExp(
        r'\]\(aurai://member/([^)]+)\)',
      ).allMatches(text).map((match) => match.group(1)!).toSet();
      final missingMentions = ids.toSet().where(
        (id) =>
            !inlineMentions.contains(Uri.encodeComponent(id)) &&
            !RegExp(
              '@${RegExp.escape(senders[id]!.name)}(?![a-zA-Z0-9_])',
            ).hasMatch(text),
      );
      output.add(
        AgentMessage(
          id: newMessageId(),
          role: AgentMessageRole.assistant,
          isGroupMessage: true,
          senderId: reply.senderId,
          sender: _groupSenders[reply.senderId]!,
          runId: member.activeRunId,
          text: [
            if (missingMentions.isNotEmpty)
              missingMentions
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
        await _groupSleeps.remove(parent.id, reply.senderId);
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
      return _deliverGroupMessage(
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
    if (output.isNotEmpty) {
      final body =
          '${reply.sender.name}：${output.map((m) => markdownPreviewText(m.text)).join('\n')}';
      completedReplies.value = ConversationCompletion(
        conversationId: parent.id,
        title: parent.title,
        runId: member.activeRunId!,
        reply: body,
      );
      unawaited(
        _platform.notifyGroupMessage(parent.id, parent.title, body).catchError((
          Object error,
        ) {
          debugPrint('Group notification failed: $error');
        }),
      );
    }
    return {
      'sent': true,
      'messageId': output.isEmpty ? null : output.single.id,
      'participation': dispatcher.paused.contains(reply.senderId)
          ? 'paused'
          : 'active',
      'instruction': '消息已发送，不要再重复。没有新的内容就结束本次执行。',
    };
  }

  Future<Map<String, Object?>> _changePrivateGroupParticipation(
    Map<String, Object?> arguments,
    String senderId,
  ) async {
    final groupId = arguments['groupId'] as String?;
    if (groupId == null) throw ArgumentError('请先确认要调整哪个群聊');
    if (arguments['message'] != null) {
      throw ArgumentError('调整接话状态时 message 必须为 null');
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
    await _applyPrivateGroupParticipation(groupId, senderId, paused);
    return {'participation': participation, 'groupId': groupId};
  }

  Future<void> _applyPrivateGroupParticipation(
    String groupId,
    String senderId,
    bool paused,
  ) async {
    try {
      final state = _executionStates[groupId];
      if (state != null) {
        if (paused) {
          state.groupDispatcher?.pause(senderId);
          await state.groupRuntimes[senderId]?.cancel();
        } else {
          state.groupDispatcher?.paused.remove(senderId);
        }
      }
      await _groupSleeps.reload();
    } on Object catch (error, stack) {
      developer.log(
        'Committed participation runtime update failed',
        error: error,
        stackTrace: stack,
      );
    }
  }
}
