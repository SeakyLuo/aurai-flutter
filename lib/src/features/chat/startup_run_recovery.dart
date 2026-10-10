part of 'chat_controller.dart';

extension StartupRunRecovery on ChatController {
  void _startRunRecovery() {
    final byConversation = <String, List<Map<String, Object?>>>{};
    for (final run in _store.startupRuns) {
      byConversation
          .putIfAbsent(run['conversation_id'] as String, () => [])
          .add(run);
    }
    // Reserve every destination before callback and sleep dispatchers start.
    _callbackConversations.addAll(byConversation.keys);
    final jobs = byConversation.entries.toList();
    var next = 0;
    Future<void> worker() async {
      while (next < jobs.length && !_callbacksDisposed) {
        final job = jobs[next++];
        await _prepareStartupRecovery(job.key, job.value);
      }
    }

    // Loading history and starting providers are bounded independently per job.
    for (var i = 0; i < 3 && i < jobs.length; i++) {
      unawaited(worker());
    }
  }

  Future<void> _prepareStartupRecovery(
    String id,
    List<Map<String, Object?>> runs,
  ) async {
    try {
      final target = await _forwardTarget(id);
      // Only preparation occupies a worker; a question waiting for an answer
      // must not prevent other conversations from recovering.
      unawaited(
        _finishStartupRecovery(
          id,
          runs,
          _inConversation(
            target,
            () => _recoverStartupConversation(target, runs),
          ),
        ),
      );
    } on Object catch (error, stack) {
      await _finishStartupRecovery(id, runs, Future<void>.error(error, stack));
    }
  }

  /// Startup owns errors from background executions and exposes them to the UI.
  Future<void> _finishStartupRecovery(
    String id,
    List<Map<String, Object?>> runs,
    Future<void> execution,
  ) async {
    try {
      await execution;
    } on Object catch (error, stack) {
      developer.log(
        'Startup execution recovery failed',
        error: error,
        stackTrace: stack,
      );
      if (!_callbacksDisposed) programErrors.value = errorMessage(error);
    } finally {
      await _store.database.rawUpdate(
        "UPDATE app_state SET value = (SELECT json_group_array(value) FROM json_each(app_state.value) WHERE value NOT IN (SELECT value FROM json_each(?))) WHERE key = 'startup_run_recovery'",
        [jsonEncode(runs.map((run) => run['id']).toList())],
      );
      _callbackConversations.remove(id);
      _callbacksPending = true;
      _callbackGeneration++;
      _drainMessageCallbacks();
    }
  }

  Future<void> _recoverStartupConversation(
    Conversation conversation,
    List<Map<String, Object?>> runs,
  ) async {
    if (hasRunningTask || conversation.isArchived) return;
    _runningConversation = conversation;
    conversation.runState = ChatRunState.running;
    try {
      if (conversation.kind == ConversationKind.group) {
        final continuations = {
          for (final run in runs)
            run['sender_id'] as String: run['id'] as String,
        };
        await _executeGroupChat(
          conversation,
          wakeMembers: continuations.keys.toSet(),
          continuationRuns: continuations,
        );
      } else {
        final run = runs.single;
        final reply = await _directReplyContext(conversation);
        if (run['provider'] != reply.config.service.name ||
            run['model'] != reply.config.model) {
          throw StateError('请切回中断时使用的模型后继续');
        }
        if (conversation.isTask) {
          await _restoreStartupQuestion(
            conversation,
            reply,
            run['id'] as String,
          );
        }
        if (conversation.runState == ChatRunState.stopping)
          throw const AgentCancelled();
        await _executePrivateMember(
          conversation,
          reply: reply,
          continuationRunId: run['id'] as String,
        );
      }
    } on AgentCancelled {
      conversation.runState = ChatRunState.cancelled;
      if (conversation.kind == ConversationKind.direct) {
        await PrivateTaskState(
          _store.database,
          conversation.id,
          runs.single['sender_id'] as String,
        ).pause('用户停止了当前执行');
      }
    } on Object {
      if (conversation.runState == ChatRunState.running) {
        conversation.runState = ChatRunState.interrupted;
      }
      rethrow;
    } finally {
      _runningConversation = null;
      await _persistRun(conversation);
      _notifyRun(conversation);
      _resumeForwardedReply();
      _drainGroupSystemNotices();
    }
  }

  Future<void> _restoreStartupQuestion(
    Conversation conversation,
    ExecutionReplyContext reply,
    String runId,
  ) async {
    final records = await Future.wait([
      _store.database.query(
        'tool_calls',
        where:
            r"run_id = ? AND name = 'askUser' AND json_extract(result_json, '$.interrupted') = 1 AND json_extract(result_json, '$.messageId') IS NOT NULL",
        whereArgs: [runId],
        orderBy: 'started_at DESC',
        limit: 1,
      ),
      _store.database.query(
        'messages',
        columns: ['id', 'interactive_json'],
        where: 'run_id = ? AND interactive_json IS NOT NULL',
        whereArgs: [runId],
      ),
    ]);
    if (conversation.runState == ChatRunState.stopping)
      throw const AgentCancelled();
    if (records[0].isEmpty) return;
    final tool = records[0].single;
    final sent =
        Map<String, Object?>.from(
            jsonDecode(tool['result_json'] as String) as Map,
          )
          ..remove('pending')
          ..remove('interrupted')
          ..remove('message');
    final call = ToolCall(
      id: tool['provider_call_id'] as String,
      name: 'askUser',
      arguments: Map<String, Object?>.from(
        jsonDecode(tool['arguments_json'] as String) as Map,
      ),
    );
    final row = records[1]
        .where((row) => row['id'] == sent['messageId'])
        .firstOrNull;
    late ToolResult result;
    if (row == null) {
      result = ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.cancelled,
        output: {'cancelled': true, 'reason': '问题消息已删除'},
      );
    } else {
      final card = InteractiveMessage.fromJson(
        jsonDecode(row['interactive_json'] as String) as Map<String, dynamic>,
      );
      if (card.completed) {
        result = ToolResult(
          callId: call.id,
          toolName: call.name,
          status: ToolResultStatus.success,
          output: {
            ...sent,
            'answers': card.choices[MessageSender.localUser.id]!['value'],
          },
        );
      } else {
        final questionTool = AskUserTool(
          conversation.id,
          (question) => _showRunQuestion(
            conversation,
            null,
            reply,
            runId,
            question,
            showProgress: false,
          ),
          sender: reply.sender,
          executionRunId: runId,
        );
        questionTool.submitCard = (id, answers) async {
          await clickInteractiveMessage(
            id,
            'answer',
            card.revision,
            card.participantRevision(MessageSender.localUser.id),
            value: answers,
            source: conversation,
          );
        };
        result = await questionTool.resume(call, sent);
      }
    }
    await _store.runs.finishTool(runId, result);
  }
}
