part of 'chat_controller.dart';

/// This is the publication boundary: model text remains private until this call.
extension GroupMessageDelivery on ChatController {
  List<String> _takeGroupRunUpdates(
    String senderId,
    List<AgentMessage> observed,
  ) {
    final dispatcher = _groupDispatcher!;
    final seen = {for (final message in observed) message.id: message};
    final updates = dispatcher.history
        .where(
          (message) =>
              !seen.containsKey(message.id) ||
              seen[message.id]!.isSystem != message.isSystem,
        )
        .toList();
    observed.removeWhere((message) => updates.any((m) => m.id == message.id));
    observed.addAll(updates);
    dispatcher.acknowledge(senderId);
    return _groupHistory(updates, senderId).map((m) => m.text).toList();
  }

  Future<Map<String, Object?>> _deliverGroupMessage({
    required Map<String, Object?> arguments,
    required Conversation member,
    required Conversation parent,
    required ExecutionReplyContext reply,
    required List<AgentMessage> observed,
    required List<String> publishedIds,
    required GroupDispatcher dispatcher,
  }) async {
    if (dispatcher.stopped || dispatcher.closed) throw const AgentCancelled();
    final groupId = arguments['groupId'] as String?;
    if (groupId != null && groupId != parent.id) {
      _checkGroupStopped(parent);
      if (_removedGroupMembers.contains(reply.senderId) ||
          member.runState == ChatRunState.stopping) {
        throw const AgentCancelled();
      }
      final result = await _sendPrivateGroupMessage(arguments, reply.senderId);
      _execution.groupReplyDrafts.remove(reply.senderId);
      return result;
    }
    _checkGroupStopped(parent);
    if (_removedGroupMembers.contains(reply.senderId) ||
        member.runState == ChatRunState.stopping) {
      throw const AgentCancelled();
    }
    final item = arguments['message'] as Map<String, Object?>?;
    if (dispatcher.isMuted(reply.senderId)) throw const AgentCancelled();
    _cacheGroupMessageDraft(reply.senderId, item);
    final seen = {for (final m in observed) m.id: m};
    final updates = dispatcher.history
        .where(
          (m) => !seen.containsKey(m.id) || seen[m.id]!.isSystem != m.isSystem,
        )
        .toList();
    dispatcher.acknowledge(reply.senderId);
    observed.removeWhere((m) => updates.any((f) => f.id == m.id));
    observed.addAll(updates);
    final fresh = updates
        .where((message) => message.canView(reply.senderId))
        .toList();
    if (fresh.isNotEmpty) {
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
              'text': _quotedInput(message, reply.senderId),
              'files': message.files.map((f) => f.toJson()).toList(),
            },
        ],
        'instruction': '先阅读新消息，再决定原样发送、修改草稿或保持沉默；不要重复已经执行的操作。',
      };
    }
    final senders = _groupSenders;
    if (!senders.containsKey(reply.senderId)) throw const AgentCancelled();
    if (item != null) {
      final routed = await MiniappGroupMessageRouter(_store.database).send(
        parent.id,
        reply.senderId,
        item,
        arguments['participation'] as String,
      );
      if (routed != null) {
        publishedIds.add(routed['messageId'] as String);
        _execution.groupReplyDrafts.remove(reply.senderId);
        return {
          ...routed,
          'participation': dispatcher.paused.contains(reply.senderId)
              ? 'paused'
              : 'active',
        };
      }
    }
    final byId = {for (final m in dispatcher.history) m.id: m};
    final mentions = <String>{};
    final output = <AgentMessage>[];
    if (item != null) {
      final audience = _messageAudience(item, senders.keys, reply.senderId);
      final excludedAudience = _messageExcludedAudience(
        item,
        senders.keys,
        reply.senderId,
      );
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
      if (source != null) {
        _checkQuoteAudience(
          source.audience,
          reply.senderId,
          source.excludedAudience,
        );
      }
      final quote = source == null
          ? null
          : (MessageQuote(
                messageId: source.id,
                senderId: source.senderId,
                audience: source.audience,
                excludedAudience: source.excludedAudience,
                text: source.text,
                markdown: source.markdown,
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
          markdown: item['markdown'] == true,
          senderId: reply.senderId,
          sender: _groupSenders[reply.senderId]!,
          audience: audience,
          excludedAudience: excludedAudience,
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
      await GroupParticipation(_store.database).set(
        parent.id,
        reply.senderId,
        participation == 'paused',
        reason: arguments['participationReason'] as String?,
      );
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
        dispatcher: dispatcher,
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
    if (dispatcher.isMuted(reply.senderId)) throw const AgentCancelled();
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
    _execution.groupReplyDrafts.remove(reply.senderId);
    observed.addAll(output);
    if (output.isNotEmpty) dispatcher.receive(output, mentions: mentions);
    _notifyMember(member, parent);
    if (output.isNotEmpty &&
        output.single.canView(MessageSender.localUser.id)) {
      final body =
          '${reply.sender.name}：${output.map((m) => m.markdown ? markdownPreviewText(m.text) : memberMentionsPlainText(m.text)).join('\n')}';
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
      if (participation == 'paused')
        'participationReason': arguments['participationReason'],
      'instruction': '消息已发送，不要重复发送。当前意思表达完整就可以结束，无需主动寻找下一处补充。',
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
    await GroupParticipation(_store.database).set(
      groupId,
      senderId,
      paused,
      reason: arguments['participationReason'] as String?,
    );
    await _applyPrivateGroupParticipation(groupId, senderId, paused);
    return {
      'participation': participation,
      'groupId': groupId,
      if (paused) 'participationReason': arguments['participationReason'],
    };
  }

  Future<void> _applyPrivateGroupParticipation(
    String groupId,
    String senderId,
    bool paused,
  ) async {
    GroupParticipation.changes.add(groupId);
    try {
      final state = _executions.sessions[groupId];
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
