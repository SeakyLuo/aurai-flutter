part of 'chat_controller.dart';

extension HtmlActions on ChatController {
  HtmlStore get htmlStore => HtmlStore(_store.database);

  Future<void> _receiveProgramChange(MiniappProgramChange change) async {
    _scheduleProgramTick();
    if (change.memberNamesChanged) {
      await refreshGroupDisplayNames(change.conversationId);
    }
    final state = _executionStates[change.conversationId];
    final dispatcher = state?.groupDispatcher;
    for (final entry in change.replyStates.entries) {
      if (entry.value) {
        dispatcher?.paused.remove(entry.key);
      } else {
        dispatcher?.pause(entry.key);
      }
    }
    await Future.wait([
      for (final entry in change.replyStates.entries)
        if (!entry.value && state?.groupRuns[entry.key]?.activeRunId != null)
          stopGroupMember(
            conversationId: change.conversationId,
            senderId: entry.key,
            runId: state!.groupRuns[entry.key]!.activeRunId!,
            currentOnly: true,
          ),
    ]);
    if (change.replyStates.isNotEmpty) await _groupSleeps.reload();
    for (final entry in change.cards.entries) {
      _replaceInteractiveCard(change.conversationId, entry.key, entry.value);
    }
    for (final effect in change.messages) {
      _publishInteractiveChange(
        change.conversationId,
        effect.message,
        notifyParticipants: effect.wakeAi,
      );
    }
    if (change.replyStates.isNotEmpty) {
      GroupParticipation.changes.add(change.conversationId);
      groupActivityChanges.value++;
    }
    _conversationChanged();
  }

  Future<void> refreshGroupDisplayNames(String groupId) async {
    final members = await groupStore.noticeMembers(groupId);
    final senders = {for (final member in members) member.id: member};
    for (final conversation in {
      ..._conversations,
      _activeConversation,
      _runningConversation,
      for (final state in _executionStates.values) state.conversation,
    }) {
      if (conversation == null || conversation.id != groupId) continue;
      conversation.noticeMembers
        ..clear()
        ..addAll(senders);
      for (final messages in [
        conversation.messages,
        if (conversation.searchMessages != null) conversation.searchMessages!,
      ]) {
        for (var i = 0; i < messages.length; i++) {
          final message = messages[i];
          if (senders[message.senderId] case final sender?) {
            messages[i] = message.withSender(sender);
          }
          if (senders[message.quote?.senderId] case final sender?) {
            message.quote!.senderName = sender.name;
          }
        }
      }
    }
    _conversationChanged();
  }

  Future<void> _scheduleProgramTick() async {
    final generation = ++_programScheduleGeneration;
    _programTimer?.cancel();
    final wake = await MiniappProgramStore(_store.database).nextWake();
    if (_callbacksDisposed ||
        generation != _programScheduleGeneration ||
        wake == null)
      return;
    final remaining = wake - DateTime.now().millisecondsSinceEpoch;
    _programTimer = Timer(
      Duration(milliseconds: remaining > 0 ? remaining : 0),
      () async {
        try {
          await MiniappProgramStore(_store.database).tick();
        } on Object catch (error, stack) {
          developer.log(
            'Miniapp callback failed',
            error: error,
            stackTrace: stack,
          );
          programErrors.value = '小程序回调失败：${errorMessage(error)}';
        } finally {
          if (!_callbacksDisposed) _scheduleProgramTick();
        }
      },
    );
  }
}
