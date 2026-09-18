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
    final actorName = actorId == MessageSender.localUser.id
        ? '你'
        : senders[actorId]!.name;
    await _store.writer.flush();
    final notice = await _store.database.transaction(
      (txn) => writeGroupNotice(
        txn,
        conversationId,
        '${actorName}唤醒了${senders[senderId]!.name}',
      ),
    );
    _publishInteractiveChange(conversationId, notice);
    await _groupSleeps.save(conversationId, senderId, DateTime.now());
    final dispatcher = _executionStates[conversationId]?.groupDispatcher;
    if (dispatcher != null && !dispatcher.closed && !dispatcher.stopped) {
      dispatcher.receiveTargeted(const [], {senderId});
    }
    return true;
  }

  Future<DateTime?> _scheduleMemberSleep(
    Conversation parent,
    Conversation member,
    String senderId,
    Duration duration,
    String draft,
  ) async {
    final dispatcher = _groupDispatcher!;
    final until = duration.isNegative ? null : DateTime.now().add(duration);
    if (until == null) {
      await _groupSleeps.remove(parent.id, senderId);
    } else {
      await _groupSleeps.save(parent.id, senderId, until);
    }
    if (dispatcher.stopped ||
        dispatcher.closed ||
        member.runState == ChatRunState.stopping ||
        dispatcher.paused.contains(senderId) ||
        _removedGroupMembers.contains(senderId)) {
      await _groupSleeps.remove(parent.id, senderId);
      throw AgentCancelled();
    }
    await _store.database.rawInsert(
      'INSERT INTO app_state(key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value',
      ['group_sleep_draft:${parent.id}:$senderId', draft],
    );
    _execution.groupReplyDrafts.remove(senderId);
    return dispatcher.sleepUntil(senderId, until);
  }

  Future<void> _recoverGroupSleep(String id, Set<String> members) async {
    final target = await _forwardTarget(id);
    await _inConversation(target, () => _recoverGroupSleepIn(id, members));
  }

  Future<void> _recoverGroupSleepIn(String id, Set<String> members) async {
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
      _runningConversation = conversation;
      _systemEventLoading = false;
      await _executeGroupChat(conversation, wakeMembers: members);
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
