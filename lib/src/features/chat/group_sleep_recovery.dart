part of 'chat_controller.dart';

extension GroupSleepRecovery on ChatController {
  GroupWakeTool _groupWakeTool(String groupId, String actorId) => GroupWakeTool(
    (senderId) => wakeGroupMember(groupId, senderId, actorId: actorId),
  );

  Future<bool> wakeGroupMember(
    String conversationId,
    String senderId, {
    String actorId = 'user:local',
  }) async {
    final members = await groupStore.members(conversationId);
    final senders = {
      for (final member in members) member.sender.id: member.sender,
    };
    if (!senders.containsKey(actorId) ||
        senders[senderId]?.kind != MessageSenderKind.agent ||
        actorId == senderId) {
      throw StateError('只能唤醒当前群聊中的其他 AI 成员');
    }
    if (!_groupSleeps.forGroup(conversationId).containsKey(senderId))
      return false;
    final actorName = senders[actorId]!.name;
    await _store.writer.flush();
    final notice = await _store.database.transaction(
      (txn) => writeGroupNotice(
        txn,
        conversationId,
        '${actorName}唤醒了${senders[senderId]!.name}',
      ),
    );
    _publishInteractiveChange(conversationId, notice);
    final dispatcher = _executionStates[conversationId]?.groupDispatcher;
    if (dispatcher != null && !dispatcher.closed && !dispatcher.stopped) {
      await _groupSleeps.remove(conversationId, senderId);
      if (!dispatcher.closed && !dispatcher.stopped) {
        dispatcher.receiveTargeted(const [], {senderId});
      } else {
        await _groupSleeps.save(conversationId, senderId, DateTime.now());
      }
    } else {
      await _groupSleeps.save(conversationId, senderId, DateTime.now());
    }
    return true;
  }

  Future<int> wakeAllGroupMembers(String conversationId) async {
    final results = await Future.wait<Object>([
      groupStore.members(conversationId),
      GroupParticipation(_store.database).paused(conversationId),
    ]);
    final members = results[0] as List<ConversationMember>;
    final paused = results[1] as Set<String>;
    final actor = members
        .firstWhere((member) => member.sender.id == MessageSender.localUser.id)
        .sender;
    final sleeping = _groupSleeps.forGroup(conversationId);
    final targets = members
        .where(
          (member) =>
              member.sender.kind == MessageSenderKind.agent &&
              sleeping.containsKey(member.sender.id) &&
              !paused.contains(member.sender.id),
        )
        .map((member) => member.sender)
        .toList();
    if (targets.isEmpty) return 0;
    final ids = targets.map((sender) => sender.id).toSet();
    await _store.writer.flush();
    final notice = await _store.database.transaction(
      (txn) => writeGroupNotice(
        txn,
        conversationId,
        '${actor.name}唤醒了${targets.map((sender) => sender.name).join('、')}',
      ),
    );
    _publishInteractiveChange(conversationId, notice);
    final dispatcher = _executionStates[conversationId]?.groupDispatcher;
    final immediate =
        dispatcher != null && !dispatcher.closed && !dispatcher.stopped;
    await _groupSleeps.wakeMembers(conversationId, ids, immediate: immediate);
    if (immediate) {
      if (!dispatcher.closed && !dispatcher.stopped) {
        dispatcher.receiveTargeted(const [], ids);
      } else {
        await _groupSleeps.saveMembers(conversationId, ids, DateTime.now());
      }
    }
    return targets.length;
  }

  Future<DateTime?> _scheduleMemberSleep(
    Conversation parent,
    Conversation member,
    String senderId,
    Duration duration,
    String draft,
    String reason,
    GroupDispatcher dispatcher,
  ) async {
    if (dispatcher.stopped ||
        dispatcher.closed ||
        member.runState == ChatRunState.stopping)
      throw const AgentCancelled();
    final until = duration.isNegative ? null : DateTime.now().add(duration);
    if (dispatcher.paused.contains(senderId) && until != null) {
      throw StateError('自动接话已关闭，不能安排定时唤醒；如需结束本次任务并等待新消息，请使用 seconds=-1');
    }
    if (until == null) {
      await _groupSleeps.remove(parent.id, senderId);
    } else {
      await _groupSleeps.save(parent.id, senderId, until);
    }
    if (dispatcher.stopped ||
        dispatcher.closed ||
        member.runState == ChatRunState.stopping ||
        _removedGroupMembers.contains(senderId)) {
      await _groupSleeps.remove(parent.id, senderId);
      throw AgentCancelled();
    }
    final batch = _store.database.batch();
    for (final entry in {'draft': draft, 'reason': reason}.entries) {
      batch.rawInsert(
        'INSERT INTO app_state(key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value',
        ['group_sleep_${entry.key}:${parent.id}:$senderId', entry.value],
      );
    }
    await batch.commit(noResult: true);
    _execution.groupReplyDrafts.remove(senderId);
    return dispatcher.sleepUntil(senderId, until);
  }

  Future<void> _recoverGroupSleep(
    String id,
    Set<String> members, {
    bool callbacksOnly = false,
    bool requireDueSleep = true,
  }) async {
    final target = await _forwardTarget(id);
    await _inConversation(
      target,
      () => _recoverGroupSleepIn(
        id,
        members,
        callbacksOnly: callbacksOnly,
        requireDueSleep: requireDueSleep,
      ),
    );
  }

  Future<void> _recoverGroupSleepIn(
    String id,
    Set<String> members, {
    bool callbacksOnly = false,
    bool requireDueSleep = true,
  }) async {
    if (hasRunningTask) return;
    _systemEventLoading = true;
    try {
      final rows = await _store.database.query(
        'conversations',
        columns: ['id'],
        where: 'id = ? AND archived = 0',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) {
        await _groupSleeps.remove(id);
        return;
      }
      final conversation = id == activeConversation.id
          ? activeConversation
          : await _store.load(id);
      final sleeps = _groupSleeps.forGroup(id);
      final now = DateTime.now();
      final recipients = callbacksOnly || !requireDueSleep
          ? {...members}
          : {
              for (final member in members)
                if (sleeps[member] case final until? when !until.isAfter(now))
                  member,
            };
      if (callbacksOnly) {
        final pending = await _store.database.query(
          'message_callbacks',
          columns: ['sender_id'],
          where:
              'conversation_id = ? AND sender_id IN (${List.filled(members.length, '?').join(',')}) AND ${MessageCallbacks.readyWhere}',
          whereArgs: [id, ...members],
          limit: 20,
        );
        final senders = pending.map((event) => event['sender_id']).toSet();
        recipients.removeWhere((member) => !senders.contains(member));
      }
      if (recipients.isEmpty) return;
      _runningConversation = conversation;
      _systemEventLoading = false;
      await _executeGroupChat(
        conversation,
        wakeMembers: recipients,
        callbacksOnly: callbacksOnly,
      );
    } on Object catch (error, stack) {
      debugPrint('Group sleep recovery failed: $error\n$stack');
    } finally {
      _systemEventLoading = false;
      _runningConversation = null;
      _resumeForwardedReply();
      _conversationChanged();
      _drainGroupSystemNotices();
    }
  }
}
