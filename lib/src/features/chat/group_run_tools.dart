part of 'chat_controller.dart';

extension GroupRunTools on ChatController {
  List<AgentTool> _groupRunTools({
    required Conversation parent,
    required Conversation member,
    required _ReplyContext reply,
    required List<AgentMessage> observed,
    required List<String> publishedIds,
    required void Function() onSleep,
  }) {
    // Bind tools to the dispatcher that owns this run, including after awaits.
    final dispatcher = _groupDispatcher!;
    return [
      GroupMuteTool(
        (senderId, duration) => setGroupMemberMute(
          parent.id,
          senderId,
          duration: duration,
          actorId: reply.senderId,
        ),
      ),
      _groupWakeTool(parent.id, reply.senderId),
      for (final pause in [true, false])
        GroupAutoReplyTool(
          pause: pause,
          change: (senderId, triggerReply) async {
            if (dispatcher.stopped || dispatcher.closed)
              throw const AgentCancelled();
            final members = await groupStore.members(parent.id);
            if (!members.any((m) => m.sender.id == reply.senderId) ||
                senderId == reply.senderId ||
                !members.any(
                  (m) =>
                      m.sender.id == senderId &&
                      m.sender.kind == MessageSenderKind.agent,
                )) {
              throw StateError('只能调整当前群聊中其他 AI 成员的自动接话');
            }
            await GroupParticipation(_store.database).set(
              parent.id,
              senderId,
              pause,
              reason: pause ? '${reply.sender.name}暂停了自动接话' : null,
            );
            if (pause) {
              dispatcher.pause(senderId);
              await _groupSleeps.remove(parent.id, senderId);
              final target = _groupRuns[senderId];
              if (target?.runState == ChatRunState.running) {
                target!.runState = ChatRunState.stopping;
                await _groupRuntimes[senderId]?.cancel();
              }
            } else {
              dispatcher.paused.remove(senderId);
              if (triggerReply) {
                await _groupSleeps.remove(parent.id, senderId);
                if (dispatcher.stopped || dispatcher.closed)
                  throw const AgentCancelled();
                dispatcher.receiveTargeted(const [], {senderId});
              }
            }
            groupActivityChanges.value++;
            notifyListeners();
          },
        ),
      GroupSleepTool((duration, draft, reason) async {
        final until = await _scheduleMemberSleep(
          parent,
          member,
          reply.senderId,
          duration,
          draft,
          reason,
          dispatcher,
        );
        onSleep();
        return until;
      }),
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
    ];
  }
}
