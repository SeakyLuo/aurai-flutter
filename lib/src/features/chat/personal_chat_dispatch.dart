part of 'chat_controller.dart';

extension PersonalChatDispatch on ChatController {
  Future<void> _executeMember(
    Conversation conversation, {
    bool scheduled = false,
    bool callbacksOnly = false,
    required ExecutionReplyContext reply,
    List<AgentMessage>? groupHistory,
    AgentMessage? groupUser,
    Conversation? groupParent,
    String? continuationRunId,
    String? sleepWakeReason,
    bool preserveAutoReplyPause = false,
  }) {
    Future<void> turn(
      bool first,
      String? wakeReason,
      AgentMessage? pendingMessage,
    ) => _executeMemberTurn(
      conversation,
      reply: reply,
      scheduled: first && scheduled,
      callbacksOnly: first && callbacksOnly,
      groupHistory: groupHistory,
      groupUser: groupUser,
      pendingMessage: pendingMessage,
      groupParent: groupParent,
      continuationRunId: first ? continuationRunId : null,
      sleepWakeReason: first ? sleepWakeReason : wakeReason,
    );
    return conversation.isPersonalChat
        ? _dispatchPersonalChat(
            conversation,
            reply,
            turn,
            preserveAutoReplyPause: preserveAutoReplyPause,
          )
        : turn(true, null, null);
  }

  Future<void> _dispatchPersonalChat(
    Conversation conversation,
    ExecutionReplyContext reply,
    Future<void> Function(
      bool first,
      String? wakeReason,
      AgentMessage? pendingMessage,
    )
    respond, {
    required bool preserveAutoReplyPause,
  }) async {
    Object? failure;
    StackTrace? failureStack;
    var first = true;
    late final ChatDispatcher dispatcher;
    dispatcher = ChatDispatcher(
      // The private model history is loaded from storage with its context window.
      // Keep only live arrivals here, so older UI messages are not reintroduced.
      history: const [],
      members: [reply.senderId],
      paused: preserveAutoReplyPause
          ? await GroupParticipation(_store.database).paused(conversation.id)
          : {},
      respond: (_, snapshot) async {
        final initial = first;
        first = false;
        try {
          if (conversation.runState == ChatRunState.stopping) {
            throw const AgentCancelled();
          }
          final woke = dispatcher.wokeFromSleep(reply.senderId);
          final pending = snapshot.where(
            (message) => !identical(
              _execution.personalDeliveredMessages[message.id],
              message,
            ),
          );
          // Live arrivals already consumed by the previous run need no new reply.
          if (!initial && !woke && pending.isEmpty) return;
          failure = null;
          failureStack = null;
          _execution.personalFailure = null;
          final pendingMessage = pending.lastOrNull;
          final reason = woke
              ? await _groupSleepDraft(
                  'group_sleep_reason:${conversation.id}:${reply.senderId}',
                )
              : null;
          if (woke) await _groupSleeps.remove(conversation.id, reply.senderId);
          await _guardPrivateReply(
            conversation,
            reply,
            () => respond(initial, reason, pendingMessage),
          );
        } on Object catch (error, stack) {
          failureStack = stack;
          rethrow;
        }
      },
      // The existing private-run boundary persists and presents reply failures.
      // Defer the card until dispatch settles, keeping per-run diagnostics.
      failed: (_, error) async {
        failure = error;
      },
    );
    _execution.personalDispatcher = dispatcher;
    _execution.personalDeliveredMessages.clear();
    try {
      dispatcher.runOnce(reply.senderId);
      await dispatcher.done;
      if (failure != null) {
        if (failure is! AgentCancelled) {
          // Failures before the reply boundary are presented by the outer guard.
          if (_execution.personalFailure case final message?) {
            conversation.messages.add(message);
            conversation.messageCount++;
            await _persistMember(conversation, null);
            _notifyRun(conversation);
          }
        }
        Error.throwWithStackTrace(failure!, failureStack!);
      }
    } finally {
      dispatcher.stop();
      _execution.personalDispatcher = null;
      _execution.personalFailure = null;
      _execution.personalDeliveredMessages.clear();
    }
  }

  Future<bool> _receivePersonalMessage(AgentMessage message) async {
    final dispatcher = _execution.personalDispatcher;
    if (dispatcher == null || dispatcher.closed || dispatcher.stopped) {
      return false;
    }
    dispatcher.hold();
    try {
      final senderId = activeConversation.defaultSenderId;
      if (message.senderId == MessageSender.localUser.id && !message.isSystem) {
        dispatcher.paused.remove(senderId);
        await _resumePrivateReply(activeConversation, senderId);
      }
      if (dispatcher.stopped) return false;
      dispatcher.history.removeWhere((item) => item.id == message.id);
      dispatcher.receiveTargeted([message], {senderId});
      if (_execution.queuedUserMessageId == message.id) {
        _execution.queuedUserMessageId = null;
      }
      return true;
    } finally {
      dispatcher.release();
    }
  }

  Future<List<Map<String, Object?>>> _takePersonalRunUpdates(
    ExecutionReplyContext reply,
    List<AgentMessage> observed,
  ) async {
    final dispatcher = _execution.personalDispatcher!;
    final delivered = _execution.personalDeliveredMessages;
    final updates = dispatcher.history
        .where((message) => !identical(delivered[message.id], message))
        .toList();
    final input = (await responseMessageInput(
      _privateHistory(updates, reply.senderId),
      supportsImages: configSupportsImageInput(reply.config),
    )).expand((items) => items).toList();
    final ids = updates.map((message) => message.id).toSet();
    observed.removeWhere((message) => ids.contains(message.id));
    observed.addAll(updates);
    for (final message in updates) {
      delivered[message.id] = message;
    }
    if (dispatcher.history.every(
      (message) => identical(delivered[message.id], message),
    )) {
      dispatcher.acknowledge(reply.senderId);
    }
    return input;
  }
}
