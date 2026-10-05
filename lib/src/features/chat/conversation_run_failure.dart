part of 'chat_controller.dart';

final _recordedRunErrors = Expando<String>('recorded run error conversation');
final _recoveryOptions =
    Expando<({String key, Future<Map<String, bool?>> value})>();

extension ConversationRunFailure on ChatController {
  Future<Map<String, bool?>> failedRecoveryOptions() {
    final conversation = activeConversation;
    final failures = conversation.messages.where((m) => m.isFailure).toList();
    final key =
        '${conversation.id}:${identityHashCode(conversation)}:${config.service.name}/${config.model}:${failures.map((m) => m.id).join(',')}:${_groupReplies.values.map((r) => '${r.config.service.name}/${r.config.model}').join(',')}';
    final cached = _recoveryOptions[this];
    if (cached?.key == key) return cached!.value;
    final future = _loadFailedRecoveryOptions(conversation, failures);
    _recoveryOptions[this] = (key: key, value: future);
    return future;
  }

  Future<Map<String, bool?>> _loadFailedRecoveryOptions(
    Conversation conversation,
    List<AgentMessage> failures,
  ) async {
    if (failures.isEmpty) return {};
    final records = await Future.wait<Object>([
      _store.database.query(
        'agent_runs',
        columns: [
          'id',
          'sender_id',
          'status',
          'provider',
          'model',
          'error_detail',
        ],
        where:
            'conversation_id = ? AND id IN (${List.filled(failures.length, '?').join(',')})',
        whereArgs: [conversation.id, ...failures.map((m) => m.runId)],
      ),
      _store.groups.groupProfiles(conversation.id),
      groupStore.mutedMembers(conversation.id),
    ]);
    final runs = {
      for (final r in records[0] as List<Map<String, Object?>>) r['id']: r,
    };
    final configs = {
      for (final p in records[1] as List<AiProfile>) p.sender.id: aiConfig(p),
    };
    final muted = records[2] as Map<String, GroupMute>;
    return {
      for (final m in failures)
        m.id:
            configs[m.senderId]?.isConfigured != true ||
                muted[m.senderId]?.isActive == true
            ? null
            : runs[m.runId]?['sender_id'] == m.senderId &&
                  (runs[m.runId]?['status'] == 'interrupted' ||
                      classifyModelFailure(
                        runs[m.runId]?['error_detail'] as String? ?? '',
                      ).canContinue) &&
                  const [
                    'failed',
                    'interrupted',
                  ].contains(runs[m.runId]?['status']) &&
                  configs[m.senderId]?.service.name ==
                      runs[m.runId]?['provider'] &&
                  configs[m.senderId]?.model == runs[m.runId]?['model'],
    };
  }

  Future<String> _logRunFailure(
    Object error,
    StackTrace stack, {
    required ModelConfig config,
    required String conversationId,
    required MessageSender sender,
    required String runId,
  }) async {
    var diagnostic = '${error.runtimeType}: $error\n$stack';
    if (config.apiKey.isNotEmpty) {
      diagnostic = diagnostic.replaceAll(config.apiKey, '[redacted]');
    }
    await ExecutionLog.write({
      'event': 'run_error',
      'conversationId': conversationId,
      'senderId': sender.id,
      'senderName': sender.name,
      'runId': runId,
      'model': config.model,
      'diagnostic': diagnostic,
    }, apiKey: config.apiKey);
    developer.log(
      '会话执行失败：${errorMessage(error)}',
      name: 'aurai.execution',
      error: error,
      stackTrace: stack,
    );
    return diagnostic;
  }

  void _recordRunError(Object error, String conversationId) {
    if (error is Exception || error is Error) {
      _recordedRunErrors[error] = conversationId;
    }
  }

  bool isRecordedRunError(Object error) =>
      (error is Exception || error is Error) &&
      _recordedRunErrors[error] == activeConversation.id;

  bool canOfferFailedRetry(AgentMessage message) =>
      activeConversation.kind == ConversationKind.group
      ? message.isFailure &&
            _groupRuns[message.senderId]?.runState != ChatRunState.running &&
            _groupDispatcher?.hasPending(message.senderId) != true &&
            activeConversation.runState != ChatRunState.stopping
      : message.role == AgentMessageRole.assistant &&
            message.runId != null &&
            activeConversation.runState == ChatRunState.failed &&
            activeConversation.activeRunId == message.runId &&
            !hasRunningTask;

  bool isFailedReplyActive(AgentMessage message) =>
      activeConversation.kind == ConversationKind.group
      ? _groupRuns[message.senderId]?.runState == ChatRunState.running ||
            _groupRuns[message.senderId]?.runState == ChatRunState.stopping ||
            _groupDispatcher?.hasPending(message.senderId) == true
      : hasRunningTask;

  Future<void> retryFailedMessage(
    AgentMessage message, {
    bool resumeAutoReply = false,
    Future<void> Function()? beforeRemoval,
  }) async {
    if (activeConversation.kind == ConversationKind.direct) {
      await retryFailedRun(message.runId);
      return;
    }
    if (!canOfferFailedRetry(message)) throw StateError('这条消息当前不能重试');
    final conversation = activeConversation;
    final members = await groupStore.members(conversation.id);
    final member = members
        .where((m) => m.sender.id == message.senderId)
        .firstOrNull;
    if (member == null || member.sender.kind != MessageSenderKind.agent) {
      throw StateError('该成员已不在群聊中');
    }
    if (member.isMuted) throw StateError('该成员已被禁言，不能重试');
    final profiles = await _store.groups.groupProfiles(conversation.id);
    final reply = _groupReplyContext(
      profiles.singleWhere((p) => p.sender.id == message.senderId),
    );
    if (!reply.config.isConfigured)
      throw StateError('请先配置 ${reply.sender.name} 使用的模型');
    final options = await _loadFailedRecoveryOptions(conversation, [message]);
    _recoveryOptions[this] = null;
    final continuation = options[message.id] == true ? message.runId : null;
    if (continuation != null) {
      await loadFailedRunProtocol(
        _store.database,
        conversation.id,
        message.senderId,
        continuation,
        reply.config,
      );
    }
    if (resumeAutoReply) {
      await resumeGroupAutoReply(conversation.id, message.senderId);
    }
    await _groupSleeps.remove(conversation.id, message.senderId);
    final dispatcher = _groupDispatcher;
    if (dispatcher != null && !dispatcher.closed && !dispatcher.stopped) {
      _groupReplies[message.senderId] = reply;
      dispatcher.hold();
      try {
        await beforeRemoval?.call();
        await _removeFailedGroupMessage(conversation, message);
        dispatcher.history.removeWhere((entry) => entry.id == message.id);
        if (continuation case final runId?) {
          _execution.groupContinuationRuns[message.senderId] = runId;
        }
        dispatcher.runOnce(message.senderId);
        _notifyRun(conversation);
      } finally {
        dispatcher.release();
      }
    } else {
      if (hasRunningTask) throw StateError('当前任务还未结束');
      await _inConversation(conversation, () async {
        _runningConversation = conversation;
        try {
          await beforeRemoval?.call();
          await _removeFailedGroupMessage(conversation, message);
          await _executeGroupChat(
            conversation,
            wakeMembers: {message.senderId},
            runOnceMembers: {message.senderId},
            continuationRuns: {
              if (continuation case final runId?) message.senderId: runId,
            },
          );
        } finally {
          _runningConversation = null;
          _resumeForwardedReply();
          _notifyRun(conversation);
        }
      });
    }
  }

  Future<void> _removeFailedGroupMessage(
    Conversation conversation,
    AgentMessage message,
  ) async {
    late int count;
    await _store.writer.mutate(() async {
      await _store.database.transaction((txn) async {
        await txn.delete(
          'messages',
          where: 'id = ? AND conversation_id = ?',
          whereArgs: [message.id, conversation.id],
        );
        final counts = await txn.rawQuery(
          'SELECT COUNT(*) AS count FROM messages WHERE conversation_id = ?',
          [conversation.id],
        );
        count = counts.single['count'] as int;
        await txn.rawUpdate(
          "UPDATE conversations SET message_count = ?, preview = (SELECT text FROM messages WHERE conversation_id = ? AND kind NOT IN ('commentary', 'reasoning', 'quick_reply') ORDER BY created_at DESC, id DESC LIMIT 1) WHERE id = ?",
          [count, conversation.id, conversation.id],
        );
        _store.writer.invalidateHistory(
          conversation.id,
          deletedMessageId: message.id,
        );
      });
    });
    conversation.messages.removeWhere((entry) => entry.id == message.id);
    conversation.searchMessages?.removeWhere((entry) => entry.id == message.id);
    conversation.messageCount = count;
    for (final member in _groupRuns.values) {
      member.messages.removeWhere((entry) => entry.id == message.id);
    }
    _notifyRun(conversation);
  }

  Future<void> retryFailedRun([String? expectedRunId]) => _inConversation(
    activeConversation,
    () => _retryFailedRun(activeConversation, expectedRunId),
  );

  Future<void> _retryFailedRun(
    Conversation conversation,
    String? expectedRunId,
  ) async {
    final runId = conversation.activeRunId;
    if (conversation.kind != ConversationKind.direct ||
        conversation.runState != ChatRunState.failed ||
        runId == null ||
        (expectedRunId != null && expectedRunId != runId)) {
      throw StateError('这次失败回复已不能重试');
    }
    if (hasRunningTask) throw StateError('当前任务还未结束');
    _submitting = true;
    _notifyRun(conversation);
    late String goal;
    try {
      await _store.writer.mutate(() async {
        await _store.database.transaction((txn) async {
          final runs = await txn.query(
            'agent_runs',
            columns: ['status', 'user_message_id'],
            where: 'id = ? AND conversation_id = ?',
            whereArgs: [runId, conversation.id],
          );
          if (runs.isEmpty || runs.single['status'] != 'failed') {
            throw StateError('这次失败回复已不能重试');
          }
          final userMessageId = runs.single['user_message_id'] as String?;
          final goals = await txn.query(
            'messages',
            columns: ['text'],
            where: 'id = ? AND conversation_id = ? AND role = ?',
            whereArgs: [userMessageId, conversation.id, 'user'],
          );
          if (goals.isEmpty) throw StateError('原消息已不存在，无法重试');
          goal = goals.single['text'] as String;
          await txn.rawUpdate(
            'UPDATE conversations SET active_run_id = CASE WHEN active_run_id = ? THEN NULL ELSE active_run_id END, run_state = ?, error_detail = NULL, pending_goal = ? WHERE id = ?',
            [runId, ChatRunState.idle.name, goal, conversation.id],
          );
        });
      });
    } finally {
      _submitting = false;
      _notifyRun(conversation);
    }
    conversation
      ..pendingGoal = goal
      ..activeRunId = null
      ..runState = ChatRunState.idle
      ..errorDetail = null
      ..executionWatch = null
      ..restoredExecutionElapsed = Duration.zero
      ..hasExecutionProcess = false
      ..executionUserMessageId = null
      ..reconnectAttempt = 0;
    conversation.steps.clear();
    conversation.unfinishedRunElapsed.remove(runId);
    conversation.cancelledRunMessages.remove(runId);
    _notifyRun(conversation);
    await _continuePending();
  }
}
