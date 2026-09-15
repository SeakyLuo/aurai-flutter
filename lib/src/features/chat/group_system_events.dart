part of 'chat_controller.dart';

extension GroupSystemEvents on ChatController {
  Set<String> _groupNoticeMentions(Iterable<AgentMessage> messages) => {
    for (final entry in _groupSenders.entries)
      if (messages.any(
        (message) =>
            !message.isSystem &&
            (message.text.contains(
                  '](aurai://member/${Uri.encodeComponent(entry.key)})',
                ) ||
                _isGroupMention(message.text, entry.value.name)),
      ))
        entry.key,
  };

  Future<void> _receiveGroupSystemNotice(
    String groupId,
    AgentMessage notice,
  ) async {
    final running = _runningConversation;
    final dispatcher = _groupDispatcher;
    if (running?.id == groupId &&
        dispatcher != null &&
        !dispatcher.closed &&
        !dispatcher.stopped) {
      dispatcher.hold();
      try {
        await _refreshGroupRoster(groupId);
        if (!running!.messages.any((m) => m.id == notice.id)) {
          running.messages.add(notice);
          running.messageCount++;
        }
        _store.writer.remember([notice]);
        _notifyRun(running);
        if (!dispatcher.history.any((m) => m.id == notice.id)) {
          dispatcher.receive([
            notice,
          ], mentions: _groupNoticeMentions([notice]));
        }
      } finally {
        dispatcher.release();
      }
      return;
    }
    if (running?.id == groupId && dispatcher?.stopped == true) return;
    _queuedSystemNotices.putIfAbsent(groupId, () => []).add(notice);
    _drainGroupSystemNotices();
  }

  Future<void> _refreshGroupRoster(String groupId) async {
    final profiles = await groupStore.groupProfiles(groupId);
    final retained = profiles.map((p) => p.sender.id).toSet();
    final removed = _groupReplies.keys
        .where((id) => !retained.contains(id))
        .toList();
    _removedGroupMembers.addAll(removed);
    for (final id in removed) {
      _groupDispatcher?.remove(id);
      final member = _groupRuns[id];
      if (member != null) member.runState = ChatRunState.stopping;
    }
    if (removed.contains(_confirmingSenderId)) {
      if (pendingConfirmation != null) resolveConfirmation(false);
      await _platform.cancelPendingInteraction();
    }
    await Future.wait([
      for (final id in removed)
        if (_groupRuntimes[id] != null) _groupRuntimes[id]!.cancel(),
    ]);
    _groupReplies
      ..clear()
      ..addEntries(
        profiles.map((p) => MapEntry(p.sender.id, _groupReplyContext(p))),
      );
    _groupSenders.removeWhere(
      (id, sender) =>
          sender.kind == MessageSenderKind.agent && !retained.contains(id),
    );
    for (final profile in profiles) {
      _groupSenders[profile.sender.id] = profile.sender;
      _removedGroupMembers.remove(profile.sender.id);
      _groupDispatcher?.add(profile.sender.id);
    }
  }

  void _drainGroupSystemNotices() {
    if (_systemEventDrainScheduled || _queuedSystemNotices.isEmpty) return;
    _systemEventDrainScheduled = true;
    scheduleMicrotask(() async {
      _systemEventDrainScheduled = false;
      if (hasRunningTask ||
          changingConversation ||
          _queuedSystemNotices.isEmpty)
        return;
      final id = _queuedSystemNotices.keys.first;
      final notices = _queuedSystemNotices.remove(id)!;
      try {
        // Reserve the execution slot before loading the saved group.
        _systemEventLoading = true;
        final loaded = id == activeConversation.id
            ? activeConversation
            : await _store.load(id);
        final conversation = id == activeConversation.id
            ? activeConversation
            : loaded;
        for (final notice in notices) {
          if (!conversation.messages.any((m) => m.id == notice.id)) {
            conversation.messages.add(notice);
            conversation.messageCount++;
          }
        }
        _store.writer.remember(notices);
        _runningConversation = conversation;
        _systemEventLoading = false;
        _notifyRun(conversation);
        await _executeGroupChat(conversation);
      } on Object catch (error, stack) {
        debugPrint('Group system event failed: $error\n$stack');
      } finally {
        _systemEventLoading = false;
        _runningConversation = null;
        _conversationChanged();
        _drainGroupSystemNotices();
      }
    });
  }
}
