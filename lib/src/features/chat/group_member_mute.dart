part of 'chat_controller.dart';

extension GroupMemberMute on ChatController {
  Future<void> setGroupWideMute(
    String groupId, {
    required Duration? duration,
  }) async {
    final state = _executionStates[groupId];
    final dispatcher = state?.groupDispatcher;
    final held = dispatcher != null && !dispatcher.closed;
    if (held) dispatcher.hold();
    try {
      await groupStore.setGroupWideMute(
        groupId,
        actorId: 'user:local',
        duration: duration,
      );
      final muted = await groupStore.mutedMembers(groupId);
      dispatcher?.mutedUntil
        ?..clear()
        ..addAll(muted);
      if (duration != Duration.zero) {
        for (final id in muted.keys) {
          final member = state?.groupRuns[id];
          if (member?.activeRunId != null)
            await stopGroupMember(
              conversationId: groupId,
              senderId: id,
              runId: member!.activeRunId!,
              currentOnly: true,
            );
          state?.groupReplyDrafts.remove(id);
        }
        await _groupSleeps.retain(
          groupId,
          _groupSleeps
              .forGroup(groupId)
              .keys
              .where((id) => !muted.containsKey(id))
              .toSet(),
        );
      }
      GroupParticipation.changes.add(groupId);
      MessageCallbacks.changes.add(null);
      groupActivityChanges.value++;
      _conversationChanged();
    } finally {
      if (held) dispatcher.release();
    }
  }

  Future<void> setGroupMemberMute(
    String groupId,
    String senderId, {
    required Duration? duration,
    String actorId = 'user:local',
  }) => setGroupMembersMute(
    groupId,
    {senderId},
    duration: duration,
    actorId: actorId,
  );

  Future<void> setGroupMembersMute(
    String groupId,
    Set<String> senderIds, {
    required Duration? duration,
    String actorId = 'user:local',
  }) async {
    final state = _executionStates[groupId];
    final dispatcher = state?.groupDispatcher;
    // Keep the dispatcher alive while persisting and cancelling an active turn.
    final held = dispatcher != null && !dispatcher.closed;
    if (held) dispatcher.hold();
    try {
      await groupStore.setMembersMute(
        groupId,
        senderIds,
        actorId: actorId,
        duration: duration,
      );
      final muted = await groupStore.mutedMembers(groupId);
      for (final senderId in senderIds) {
        dispatcher?.mute(senderId, muted[senderId]);
      }
      for (final senderId in senderIds) {
        if (muted.containsKey(senderId)) {
          final member = state?.groupRuns[senderId];
          if (member?.activeRunId != null) {
            await stopGroupMember(
              conversationId: groupId,
              senderId: senderId,
              runId: member!.activeRunId!,
              currentOnly: true,
            );
          }
          state?.groupReplyDrafts.remove(senderId);
        }
      }
      await _groupSleeps.reload();
      GroupParticipation.changes.add(groupId);
      MessageCallbacks.changes.add(null);
      groupActivityChanges.value++;
      _conversationChanged();
    } finally {
      if (held) dispatcher.release();
    }
  }
}
