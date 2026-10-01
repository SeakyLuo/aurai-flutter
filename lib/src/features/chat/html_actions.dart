part of 'chat_controller.dart';

extension HtmlActions on ChatController {
  HtmlStore get htmlStore => HtmlStore(_store.database);

  void _receiveProgramChange(MiniappProgramChange change) {
    _scheduleProgramTick();
    final state = _executionStates[change.conversationId];
    final dispatcher = state?.groupDispatcher;
    for (final entry in change.replyStates.entries) {
      if (entry.value) {
        dispatcher?.paused.remove(entry.key);
      } else {
        dispatcher?.pause(entry.key);
        final member = state?.groupRuns[entry.key];
        if (member != null) member.runState = ChatRunState.stopping;
      }
    }
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
