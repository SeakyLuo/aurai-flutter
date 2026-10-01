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
        change: (groupId, senderId, triggerReply) async {
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
          if (groups.isEmpty ||
              groups.single['kind'] != 'group' ||
              !members.any((m) => m.sender.id == actorId) ||
              !members.any(
                (m) =>
                    m.sender.id == senderId &&
                    m.sender.kind == MessageSenderKind.agent,
              )) {
            throw StateError('只能调整你已加入的群聊中 AI 成员的自动接话');
          }
          final state = _executionStates[groupId];
          final dispatcher = state?.groupDispatcher;
          final active =
              dispatcher != null && !dispatcher.closed && !dispatcher.stopped;
          if (active) dispatcher.hold();
          try {
            final actor = members
                .firstWhere((m) => m.sender.id == actorId)
                .sender;
            await GroupParticipation(_store.database).set(
              groupId,
              senderId,
              pause,
              reason: pause ? '${actor.name}暂停了自动接话' : null,
            );
            if (pause) {
              dispatcher?.pause(senderId);
              await _groupSleeps.remove(groupId, senderId);
              final target = state?.groupRuns[senderId];
              if (target?.runState == ChatRunState.running) {
                target!.runState = ChatRunState.stopping;
                if (senderId != actorId)
                  await state!.groupRuntimes[senderId]?.cancel();
              }
            } else {
              dispatcher?.paused.remove(senderId);
              if (triggerReply) {
                if (active) {
                  await _groupSleeps.remove(groupId, senderId);
                  dispatcher.receiveTargeted(const [], {senderId});
                } else {
                  await _groupSleeps.save(groupId, senderId, DateTime.now());
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
