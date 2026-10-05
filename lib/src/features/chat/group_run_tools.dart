part of 'chat_controller.dart';

extension GroupRunTools on ChatController {
  void _bindGroupRunTools({
    required List<AgentTool> tools,
    required Conversation parent,
    required Conversation member,
    required _ReplyContext reply,
    required List<AgentMessage> observed,
    required List<String> publishedIds,
    required void Function() onSleep,
  }) {
    // Bind tools to the dispatcher that owns this run, including after awaits.
    final dispatcher = _groupDispatcher!;
    tools.removeWhere(
      (t) =>
          t.definition.name == 'sendGroupMessage' ||
          t.definition.name == 'sleepGroupChat',
    );
    tools.addAll([
      GroupSleepTool((targetGroupId, duration, draft, reason) async {
        final until = targetGroupId == parent.id
            ? await _scheduleMemberSleep(
                parent,
                member,
                reply.senderId,
                duration,
                draft,
                reason,
                dispatcher,
              )
            : await _sleepInTargetGroup(
                targetGroupId,
                reply.senderId,
                duration,
                draft,
                reason,
              );
        if (targetGroupId == parent.id) onSleep();
        return until;
      }, currentGroupId: parent.id),
      GroupMessageTool(
        (arguments) => _deliverGroupMessage(
          arguments: arguments,
          member: member,
          parent: parent,
          reply: reply,
          observed: observed,
          publishedIds: publishedIds,
          dispatcher: dispatcher,
        ),
      ),
    ]);
  }

  List<AgentTool> _groupAutoReplyTools(
    String? currentGroupId,
    String actorId,
  ) => [
    for (final pause in [true, false])
      GroupAutoReplyTool(
        pause: pause,
        currentGroupId: currentGroupId,
        change: (groupId, senderIds, all, triggerReply) async {
          final results = await Future.wait<Object>([
            _store.database.query(
              'conversations',
              columns: ['kind'],
              where: 'id = ?',
              whereArgs: [groupId],
              limit: 1,
            ),
            groupStore.members(groupId),
          ]);
          final groups = results[0] as List<Map<String, Object?>>;
          final members = results[1] as List<ConversationMember>;
          final targets = all
              ? members
                    .where((m) => m.sender.kind == MessageSenderKind.agent)
                    .map((m) => m.sender.id)
                    .toSet()
              : senderIds;
          if (targets.isEmpty) throw StateError('群内没有目标成员');
          if (groups.isEmpty ||
              groups.single['kind'] != 'group' ||
              !members.any((m) => m.sender.id == actorId) ||
              !targets.every(
                (id) => members.any(
                  (m) =>
                      m.sender.id == id &&
                      m.sender.kind == MessageSenderKind.agent &&
                      !m.isMuted,
                ),
              )) {
            throw StateError('只能调整你已加入的群聊中成员的自动接话');
          }
          final actorMember = members.firstWhere((m) => m.sender.id == actorId);
          if ((all || senderIds.length > 1) && !actorMember.role.canManage)
            throw StateError('只有群主和群管理员可以批量暂停或恢复接话');
          final state = _executionStates[groupId];
          final dispatcher = state?.groupDispatcher;
          final active =
              dispatcher != null && !dispatcher.closed && !dispatcher.stopped;
          if (active) dispatcher.hold();
          try {
            final actor = members
                .firstWhere((m) => m.sender.id == actorId)
                .sender;
            await GroupParticipation(_store.database).setMembers(
              groupId,
              targets,
              pause,
              reason: pause ? actor.name + '暂停了自动接话' : null,
            );
            if (pause) {
              for (final senderId in targets) {
                dispatcher?.pause(senderId);
                final target = state?.groupRuns[senderId];
                if (target?.runState == ChatRunState.running)
                  target!.runState = ChatRunState.stopping;
              }
              await Future.wait([
                for (final id in targets)
                  if (id != actorId && state?.groupRuntimes[id] != null)
                    state!.groupRuntimes[id]!.cancel(),
                _groupSleeps.reload(),
              ]);
            } else {
              dispatcher?.paused.removeAll(targets);
              if (triggerReply) {
                if (active) {
                  await _groupSleeps.wakeMembers(
                    groupId,
                    targets,
                    immediate: true,
                  );
                  dispatcher.receiveTargeted(const [], targets);
                } else {
                  await _groupSleeps.saveMembers(
                    groupId,
                    targets,
                    DateTime.now(),
                  );
                }
              }
            }
            groupActivityChanges.value++;
            notifyListeners();
          } finally {
            if (active) dispatcher.release();
          }
        },
      ),
  ];
}
