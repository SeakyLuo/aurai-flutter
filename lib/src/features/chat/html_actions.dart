part of 'chat_controller.dart';

extension HtmlActions on ChatController {
  HtmlStore get htmlStore => HtmlStore(_store.database);

  Future<void> _interruptProgram(MiniappProgramChange change) async {
    bool belongs(AgentMessage message) =>
        message.messageMetadata?.participation['_programMessage'] ==
        change.messageId;
    _queuedSystemNotices[change.conversationId]?.removeWhere(belongs);
    if (_queuedSystemNotices[change.conversationId]?.isEmpty == true) {
      _queuedSystemNotices.remove(change.conversationId);
    }
    final state = _executions.sessions[change.conversationId];
    if (state == null) return;
    final target = state.conversation!;
    if (target.messages.any(
      (m) => m.id == state.queuedUserMessageId && belongs(m),
    )) {
      state.queuedUserMessageId = null;
      state.forwardedReplyPending = false;
    }
    final cancellations = <Future<void>>[];
    for (final entry in state.programRuns.entries.toList()) {
      final run = entry.value;
      if (run.messageId != change.messageId) continue;
      final current = target.kind == ConversationKind.group
          ? state.groupRuntimes[entry.key]
          : state.runtime;
      if (!identical(current, run.runtime)) continue;
      if (target.kind == ConversationKind.group) {
        state.groupRuns[entry.key]!.runState = ChatRunState.stopping;
        state.groupReplyDrafts.remove(entry.key);
        if (state.groupDispatcher!.history.lastOrNull case final last?) {
          if (belongs(last)) state.groupDispatcher!.interrupt(entry.key);
        }
      } else {
        target.runState = ChatRunState.stopping;
      }
      cancellations.add(run.runtime.cancel());
      state.programRuns.remove(entry.key);
    }
    await Future.wait(cancellations);
  }

  Future<void> _receiveProgramChange(MiniappProgramChange change) async {
    _scheduleProgramTick();
    if (change.memberNamesChanged) {
      await refreshGroupDisplayNames(change.conversationId);
    }
    final state = _executions.sessions[change.conversationId];
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
    final target = await _forwardTarget(change.conversationId);
    for (final effect in change.messages) {
      _publishInteractiveChange(
        change.conversationId,
        effect.message,
        source: target,
        notifyParticipants:
            effect.wakeAi && target.kind == ConversationKind.group,
      );
      if (effect.wakeAi && target.kind == ConversationKind.direct) {
        await _inConversation(target, () async {
          _execution.queuedUserMessageId = effect.message.id;
          await _deliverForwardedMessage(target, effect.message);
        });
      }
    }
    if (change.replyStates.isNotEmpty) {
      GroupParticipation.changes.add(change.conversationId);
      groupActivityChanges.value++;
    }
    _conversationChanged();
    if (change.markActorId case final actorId?) {
      try {
        await GroupMessageMarks(
          groupStore,
          actorId: actorId,
        ).favorite(change.conversationId, change.messageId, true);
      } on Object catch (error, stack) {
        developer.log('Miniapp mark failed', error: error, stackTrace: stack);
        programErrors.value = '小程序标记失败：${errorMessage(error)}';
      }
    }
    if (change.pinActorId case final actorId?) {
      // Pinning is independent of the committed game state and AI delivery.
      try {
        await GroupMessageMarks(
          groupStore,
          actorId: actorId,
        ).pin(change.conversationId, change.messageId, true);
      } on Object catch (error, stack) {
        developer.log('Miniapp pin failed', error: error, stackTrace: stack);
        programErrors.value = '小程序置顶失败：${errorMessage(error)}';
      }
    }
  }

  Future<void> refreshGroupDisplayNames(String groupId) async {
    final members = await groupStore.noticeMembers(groupId);
    final senders = {for (final member in members) member.id: member};
    for (final conversation in {
      ..._conversations,
      _activeConversation,
      _runningConversation,
      for (final state in _executions.sessions.values) state.conversation,
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
