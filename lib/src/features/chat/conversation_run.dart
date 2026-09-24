part of 'chat_controller.dart';

extension ConversationRun on ChatController {
  Future<void> _executeMember(
    Conversation runConversation, {
    bool scheduled = false,
    bool callbacksOnly = false,
    required _ReplyContext reply,
    List<AgentMessage>? groupHistory,
    AgentMessage? groupUser,
    Conversation? groupParent,
  }) async {
    final summaryOwner = groupParent ?? runConversation;
    final historyVersion = _store.writer.historyVersion(summaryOwner.id);
    final alongsideGroup = identical(runConversation, _privateConversation);
    final messages = runConversation.messages;
    final steps = runConversation.steps;
    final runConfig = reply.config;
    final diagnosticCalls = <String, Object?>{};
    final sleepDraftKey =
        'group_sleep_draft:${runConversation.id}:${reply.senderId}';
    final sleepDraftRows = groupParent == null
        ? const <Map<String, Object?>>[]
        : await _store.database.query(
            'app_state',
            columns: ['value'],
            where: 'key = ?',
            whereArgs: [sleepDraftKey],
          );
    final sleepDraft = sleepDraftRows.isEmpty
        ? ''
        : sleepDraftRows.single['value'] as String;
    var leftSleepDraft = false;
    final systemPrompt = groupParent == null
        ? reply.systemPrompt
        : '${reply.systemPrompt}\n'
              '${_groupDispatcher!.wokeFromSleep(reply.senderId) ? "这是你自己安排的睡眠到期，重新看看最新群聊；不代表用户发了新指令。" : "这是群消息触发的接话机会。"}';
    final memory = await aiMemory(
      reply.profile,
      scope: groupHistory == null ? '' : runConversation.id,
    );
    final skills = await aiSkills(reply.senderId);
    final documents = AiDocumentScope(_store.database, reply.senderId);
    await documents.initialize();
    final customInstructions = reply.profile.preferences.customInstructions;
    final responsePreferences = reply.profile.preferences.responses;
    final memoryRevision = memory.revision;
    final callbackEvents = await MessageCallbacks(
      _store.database,
    ).pending(runConversation.id, reply.senderId);
    if (callbacksOnly && callbackEvents.isEmpty) return;
    final htmlEvents = await _pendingHtmlEvents(
      runConversation,
      reply.senderId,
    );
    await _persistMember(runConversation, groupParent);
    final history =
        groupHistory ??
        await _store.reader.messages(
          runConversation.id,
          forModel: true,
          modelConfig: runConfig,
          afterCheckpoint: runConversation.contextSummary?.throughMessageId,
        );
    final lastUser = history.lastIndexWhere(
      (message) => message.role == AgentMessageRole.user,
    );
    if (groupParent == null &&
        callbackEvents.isEmpty &&
        lastUser >= 0 &&
        history[lastUser].id == _execution.queuedUserMessageId) {
      _execution.queuedUserMessageId = null;
    }
    final userMessage = callbackEvents.isNotEmpty
        ? _callbackContext(callbackEvents)
        : groupUser ?? history[lastUser];
    final continuationProtocol = groupParent == null && callbackEvents.isEmpty
        ? await loadTaskContinuationProtocol(
            _store.database,
            runConversation.id,
            userMessage.id,
            runConfig,
          )
        : const <Map<String, Object?>>[];
    final previousWatch = runConversation.executionWatch;
    final continuingElapsed =
        runConversation.executionUserMessageId == userMessage.id
        ? runConversation.restoredExecutionElapsed +
              (previousWatch?.elapsed ?? Duration.zero)
        : Duration.zero;
    final executionWatch = Stopwatch()..start();
    runConversation.executionWatch = executionWatch;
    runConversation.restoredExecutionElapsed = continuingElapsed;
    runConversation.hasExecutionProcess =
        continuingElapsed > Duration.zero || continuationProtocol.isNotEmpty;
    runConversation.executionUserMessageId = userMessage.id;
    final runId = await _store.runs.start(
      runConversation.id,
      callbackEvents.lastOrNull?['message_id'] as String? ?? userMessage.id,
      runConfig,
      senderId: reply.senderId,
      group: groupParent != null,
      callbackEventId: callbackEvents.lastOrNull?['id'] as String?,
      systemPrompt: systemPrompt ?? agentSystemPrompt,
      customInstructions: customInstructions,
      responsePreferences: responsePreferences,
    );
    runConversation.activeRunId = runId;
    steps.clear();
    final runStepStart = runConversation.liveToolSteps.length;
    runConversation.errorDetail = null;
    if (runConversation.runState != ChatRunState.stopping) {
      runConversation.runState = ChatRunState.running;
    }
    if (groupHistory == null && !alongsideGroup) {
      _deniedConfirmations.clear();
      _accessibilityDeclined = false;
    }
    _notifyMember(runConversation, groupParent);
    var sessionStarted = groupHistory != null || alongsideGroup;
    var outcome = 'failed';
    var producedFinalAnswer = false;
    String? failureDiagnostic;
    String? unfinishedFinalMessageId;
    final activities = <AgentTaskActivity>[];
    final runMessageIds = <String>[];
    final observed = List<AgentMessage>.of(history);
    final awaitedRoster = _groupSenders.values
        .map((m) => {'id': m.id, 'name': m.name})
        .toList();
    try {
      if (!sessionStarted) {
        await _platform.startAgentSession(
          scheduled ? '正在执行定时任务' : '正在回复',
          conversationId: runConversation.id,
        );
        sessionStarted = true;
      }
      await _persistMember(runConversation, groupParent);
      await refreshCapabilities();
      if (runConversation.runState == ChatRunState.stopping)
        throw AgentCancelled();
      final provider = switch (runConfig.service) {
        ModelService.openAi => OpenAiResponsesProvider(
          runConfig,
          systemPrompt: systemPrompt,
          summaryConfig: modelSettings.activeConfig,
          sharedContext: groupParent?.sharedContext,
        ),
        _ => DeepSeekResponsesProvider(
          runConfig,
          systemPrompt: systemPrompt,
          summaryConfig: modelSettings.activeConfig,
          sharedContext: groupParent?.sharedContext,
        ),
      };
      final webSources = WebSourceRegistry();
      final tools = _createTools(
        conversation: groupParent ?? runConversation,
        senderId: reply.senderId,
        messageId: userMessage.id,
        providerLabel: runConfig.displayName,
        memory: memory,
        skills: skills,
        documents: documents,
        history: observed,
        webSources: webSources,
        groupId: groupHistory == null ? null : runConversation.id,
        questionTool: AskUserTool(runConversation.id, (question) {
          pendingQuestion = question;
          final target = groupParent ?? runConversation;
          if (question == null || question.isUserAction) {
            target.pendingQuestionPreviews.remove(runId);
          } else {
            final title = question.title?.trim();
            final label = title == null || title.isEmpty
                ? question.question
                : title;
            final preview = '${reply.sender.name}：[问题] $label';
            target.pendingQuestionPreviews[runId] = preview;
            questionNotifications.value = ConversationCompletion(
              conversationId: target.id,
              title: target.title,
              runId: runId,
              reply: preview,
            );
          }
          unawaited(
            _platform.updateAttentionNotification(
              runConversation.id,
              'question',
              title: question == null
                  ? null
                  : (question.isUserAction ? '等待你操作' : '等待你的回答'),
              body: question?.question,
            ),
          );
          if (question != null &&
              sessionStarted &&
              groupHistory == null &&
              !alongsideGroup) {
            unawaited(
              _platform.updateAgentSessionStep(
                question.isUserAction ? '等待你操作' : '等待你的回答',
                conversationId: runConversation.id,
              ),
            );
          }
          _notifyMember(runConversation, groupParent);
        }),
      )..add(_hideThinkingTool(runConversation, groupParent));
      if (groupParent != null) {
        tools.removeWhere((t) => t.definition.name == 'sendGroupMessage');
        tools.addAll(
          _groupRunTools(
            parent: groupParent,
            member: runConversation,
            reply: reply,
            observed: observed,
            publishedIds: runMessageIds,
            onSleep: () => leftSleepDraft = true,
          ),
        );
      }
      final registry = ToolRegistry(tools: tools, capabilities: capabilities);
      registry.load(
        await recentConversationTools(_store.database, runConversation.id),
      );
      registry.load([
        'sendGroupMessage',
        if (groupParent != null) ...['sleepGroupChat', 'wakeGroupMember'],
      ]);
      Future<bool> confirm(ToolCall call, ToolDefinition definition) =>
          _confirm(
            call,
            definition,
            runId: runId,
            conversationId: runConversation.id,
            senderId: reply.senderId,
            screenAccess: reply.profile.preferences.screenAccess,
          );
      final executor = GroupToolExecutor(
        registry: registry,
        confirm: confirm,
        queue: _groupToolQueue,
        owner: _execution,
        waitForInteraction: () async {
          await pendingQuestion?.result.future;
        },
        cancelled: () =>
            groupParent?.runState == ChatRunState.stopping ||
            runConversation.runState == ChatRunState.stopping,
      );
      final runtime = AgentRuntime(
        provider: provider,
        registry: registry,
        executor: executor,
      );
      if (groupParent == null) {
        _runtime = runtime;
      } else {
        _groupRuntimes[reply.senderId] = runtime;
      }
      if (runConversation.runState == ChatRunState.stopping)
        throw AgentCancelled();
      var turnOrdinal = 0;
      late String modelTurnId;
      final stepActivityIndices = <int>[];
      String? turnMessageId;
      int? turnActivityIndex;
      String? reasoningMessageId;
      int? reasoningActivityIndex, outputMessageIndex;
      await runtime.run(
        endsRun: groupParent == null
            ? null
            : (result) =>
                  result.toolName == 'sleepGroupChat' &&
                  result.status == ToolResultStatus.success,
        conversation: [
          ...(groupHistory == null
              ? List.unmodifiable(history.take(lastUser + 1))
              : _groupHistory([
                  ...history,
                  if (htmlEvents.isNotEmpty) _htmlEventContext(htmlEvents),
                ], reply.senderId)),
          if (callbackEvents.isNotEmpty) _callbackContext(callbackEvents),
          if (continuationProtocol.isNotEmpty)
            AgentMessage(
              id: 'continuation:$runId',
              role: AgentMessageRole.assistant,
              senderId: reply.senderId,
              sender: reply.sender,
              text: '',
              createdAt: DateTime.now(),
              responseInput: continuationProtocol,
            ),
          if (groupParent != null)
            if (_takeGroupReplyDraft(reply.senderId) case final draft?) draft,
        ],
        contextSummary: groupHistory == null
            ? runConversation.contextSummary
            : groupParent!.contextSummary,
        personalContext: () async => [
          responsePreferences.instructions,
          if (groupParent != null && sleepDraft.isNotEmpty)
            '你上次休眠前留下的私人草稿（尚未发送）：\n$sleepDraft\n请结合最新消息决定保留、改写或放弃；不要自动发送，也不要当作用户的新指令。',
          if (customInstructions.isNotEmpty) '用户自定义指令：\n$customInstructions',
          if (runConversation.usesPersonalization) await memory.sharedContext(),
          if (runConversation.isTemporary) '当前为临时会话，不得将本次内容写入长期记忆。',
          if (alongsideGroup) '群聊正在后台进行；当前私聊仍可使用完整工具集。共享手机界面和用户交互由执行器互斥协调。',
          if (groupParent != null) '当前群成员：${jsonEncode((awaitedRoster))}',
        ].join('\n\n'),
        onContextSummary: (summary) async {
          final owner = groupParent ?? runConversation;
          await _store.writer.saveContextSummary(
            owner.id,
            summary,
            historyVersion: historyVersion,
          );
          if (_store.writer.historyVersion(owner.id) == historyVersion) {
            owner.contextSummary = summary;
          }
        },
        onCompactionChanged: (active) {
          if (groupParent != null) return;
          runConversation.isCompacting = active;
          _notifyMember(runConversation, groupParent);
        },
        onTurnStarted: () async {
          modelTurnId = await _store.runs.startTurn(
            runConversation.id,
            runId,
            turnOrdinal++,
          );
          turnMessageId = null;
          turnActivityIndex = null;
          reasoningMessageId = null;
          reasoningActivityIndex = null;
          outputMessageIndex = null;
          _setMemberStreaming(reply.senderId, null, groupParent);
          _notifyMember(runConversation, groupParent);
        },
        onTurnCompleted: (turn) async {
          await _persistMember(runConversation, groupParent);
          await _store.runs.finishTurn(modelTurnId, turn);
        },
        onToolStarted: (call) async {
          diagnosticCalls[call.id] = ExecutionLog.argumentShape(call.arguments);
          await _store.runs.startTool(
            runConversation.id,
            runId,
            modelTurnId,
            call,
          );
        },
        onToolCompleted: (result) async {
          await _store.runs.finishTool(runId, result);
          final shape = diagnosticCalls.remove(result.callId);
          if (result.status == ToolResultStatus.error) {
            await ExecutionLog.write({
              'event': 'tool_error',
              'conversationId': runConversation.id,
              'senderId': reply.senderId,
              'senderName': reply.sender.name,
              'runId': runId,
              'model': runConfig.model,
              'callId': result.callId,
              'tool': result.toolName,
              'argumentShape': shape,
              'result': result.output,
            }, apiKey: runConfig.apiKey);
          }
        },
        onReconnect: (attempt) {
          if (runConversation.reconnectAttempt == attempt) return;
          runConversation.reconnectAttempt = attempt;
          _notifyMember(runConversation, groupParent);
        },
        onMessageStarted: (index) {
          if (outputMessageIndex == index) return;
          outputMessageIndex = index;
          turnMessageId = null;
          turnActivityIndex = null;
        },
        onProcessingStarted: () {
          if (groupParent != null) return;
          if (runConversation.hasExecutionProcess) return;
          runConversation.hasExecutionProcess = true;
          _notifyMember(runConversation, groupParent);
        },
        onReasoningChanged: (text) {
          if (runConversation.thinkingHidden || text.trim().isEmpty) return;
          if (groupParent != null) {
            _recordGroupThought(reply.senderId, runId, turnOrdinal, text);
            return;
          }
          if (reasoningMessageId == null) {
            reasoningMessageId = newMessageId();
            runMessageIds.add(reasoningMessageId!);
            reasoningActivityIndex = activities.length;
            activities.add(
              AgentTaskActivity(
                text: text,
                messageId: reasoningMessageId,
                isReasoning: true,
              ),
            );
            messages.add(
              AgentMessage(
                id: reasoningMessageId!,
                role: AgentMessageRole.assistant,
                senderId: reply.senderId,
                sender: reply.sender,
                runId: runId,
                modelTurnId: modelTurnId,
                text: text,
                createdAt: DateTime.now(),
                isReasoning: true,
              ),
            );
            runConversation.messageCount++;
          } else {
            final index = messages.indexWhere(
              (message) => message.id == reasoningMessageId,
            );
            final previous = messages[index];
            messages[index] = AgentMessage(
              id: previous.id,
              role: previous.role,
              senderId: previous.senderId,
              sender: previous.sender,
              runId: previous.runId,
              modelTurnId: previous.modelTurnId,
              text: text,
              createdAt: previous.createdAt,
              isReasoning: true,
            );
          }
          activities[reasoningActivityIndex!] = AgentTaskActivity(
            text: text,
            messageId: reasoningMessageId,
            isReasoning: true,
          );
          _setMemberStreaming(reply.senderId, reasoningMessageId, groupParent);
          _notifyMember(runConversation, groupParent);
        },
        onTextChanged: (text) {
          if (_cacheGroupReplyText(
            groupParent,
            runConversation,
            reply.senderId,
            text,
          ))
            return;
          if (text.trim().isEmpty) return;
          if (turnMessageId == null) {
            turnMessageId = newMessageId();
            runMessageIds.add(turnMessageId!);
            turnActivityIndex = activities.length;
            activities.add(
              AgentTaskActivity(text: text, messageId: turnMessageId),
            );
            messages.add(
              AgentMessage(
                id: turnMessageId!,
                role: AgentMessageRole.assistant,
                senderId: reply.senderId,
                sender: reply.sender,
                runId: runId,
                modelTurnId: modelTurnId,
                text: text,
                createdAt: DateTime.now(),
              ),
            );
            runConversation.messageCount++;
          } else {
            final index = messages.indexWhere((m) => m.id == turnMessageId);
            final previous = messages[index];
            messages[index] = AgentMessage(
              id: previous.id,
              role: previous.role,
              senderId: previous.senderId,
              sender: previous.sender,
              runId: previous.runId,
              modelTurnId: previous.modelTurnId,
              text: text,
              createdAt: previous.createdAt,
            );
          }
          activities[turnActivityIndex!] = AgentTaskActivity(
            text: text,
            messageId: turnMessageId,
          );
          _setMemberStreaming(reply.senderId, turnMessageId, groupParent);
          _notifyMember(runConversation, groupParent);
        },
        onStepsChanged: (newSteps) {
          if (groupParent != null) {
            newSteps = newSteps
                .where((s) => s.toolName != 'sendGroupMessage')
                .toList();
          }
          if (groupParent != null && newSteps.isNotEmpty) {
            runConversation.hasExecutionProcess = true;
          }
          final liveSteps = runConversation.liveToolSteps;
          for (var i = 0; i < newSteps.length; i++) {
            final step = newSteps[i];
            final liveIndex = runStepStart + i;
            if (liveIndex < liveSteps.length &&
                identical(liveSteps[liveIndex].step, step))
              continue;
            if (liveIndex == liveSteps.length) {
              liveSteps.add((
                runId: runId,
                afterMessageId: messages.last.id,
                step: step,
              ));
            } else {
              liveSteps[liveIndex] = (
                runId: runId,
                afterMessageId: liveSteps[liveIndex].afterMessageId,
                step: step,
              );
            }
            final activity = AgentTaskActivity(
              text: step.title,
              toolName: step.toolName,
              status: step.status,
              requestJson: step.requestJson,
              resultJson: step.resultJson,
            );
            if (i == stepActivityIndices.length) {
              stepActivityIndices.add(activities.length);
              activities.add(activity);
            } else {
              activities[stepActivityIndices[i]] = activity;
            }
          }
          _setMemberStreaming(reply.senderId, null, groupParent);
          steps
            ..clear()
            ..addAll(newSteps);
          final runningStep = newSteps.where(
            (step) => step.status == AgentStepStatus.running,
          );
          if (sessionStarted && groupHistory == null && !alongsideGroup)
            unawaited(
              _platform.updateAgentSessionStep(
                runningStep.isEmpty ? '正在分析结果' : runningStep.last.title,
                conversationId: runConversation.id,
              ),
            );
          _notifyMember(runConversation, groupParent);
        },
      );
      for (final message in messages.where(
        (m) =>
            m.runId == runId && (m.interactive != null || m.htmlGame != null),
      )) {
        if (!runMessageIds.contains(message.id)) runMessageIds.add(message.id);
      }
      executionWatch.stop();
      final hasReasoning = activities.any((activity) => activity.isReasoning);
      if (runMessageIds.isNotEmpty &&
          (runConversation.hasExecutionProcess || hasReasoning)) {
        final answerIndex = messages.lastIndexWhere(
          (m) => runMessageIds.contains(m.id),
        );
        final answer = messages[answerIndex];
        final hasFinalAnswer =
            !answer.isReasoning &&
            answer.interactive == null &&
            answer.htmlGame == null &&
            answer.text.isNotEmpty;
        producedFinalAnswer = hasFinalAnswer;
        messages[answerIndex] = AgentMessage(
          id: answer.id,
          role: answer.role,
          isGroupMessage: answer.isGroupMessage,
          isReasoning: answer.isReasoning,
          senderId: answer.senderId,
          sender: answer.sender,
          runId: answer.runId,
          modelTurnId: answer.modelTurnId,
          text: answer.text,
          createdAt: answer.createdAt,
          images: answer.images,
          interactive: answer.interactive,
          htmlGame: answer.htmlGame,
          quote: answer.quote,
          taskSummary: AgentTaskSummary(
            elapsedMilliseconds:
                runConversation.restoredExecutionElapsed.inMilliseconds +
                executionWatch.elapsedMilliseconds,
            isTask: runConversation.hasExecutionProcess,
            intermediateMessageIds: List.unmodifiable(
              groupParent == null && hasFinalAnswer
                  ? runMessageIds.where(
                      (id) =>
                          id != answer.id &&
                          !messages.any(
                            (m) => m.id == id && m.interactive != null,
                          ),
                    )
                  : <String>[],
            ),
            activities: List.unmodifiable(
              groupParent != null
                  ? activities.where((a) => a.toolName != null)
                  : !hasFinalAnswer
                  ? activities.where((a) => a.toolName != null)
                  : activities.take(
                      activities.indexWhere(
                        (activity) => activity.messageId == answer.id,
                      ),
                    ),
            ),
          ),
        );
      }
      await _persistMember(runConversation, groupParent);
      await _store.runs.finish(
        runId,
        'completed',
        executionWatch.elapsedMilliseconds,
        keepPendingGoal: _execution.queuedUserMessageId != null,
        finalMessageId: runMessageIds.isEmpty
            ? null
            : messages.lastWhere((m) => runMessageIds.contains(m.id)).id,
        isTask: runConversation.hasExecutionProcess,
      );
      if (producedFinalAnswer) runConversation.liveToolSteps.clear();
      if (groupHistory == null && _execution.queuedUserMessageId == null)
        runConversation.pendingGoal = null;
      if (runConversation.runState != ChatRunState.stopping) {
        runConversation.runState = ChatRunState.idle;
      }
      outcome = 'completed';
    } on Object catch (error, stack) {
      failureDiagnostic = '${error.runtimeType}: $error\n$stack';
      if (runConfig.apiKey.isNotEmpty) {
        failureDiagnostic = failureDiagnostic.replaceAll(
          runConfig.apiKey,
          '[redacted]',
        );
      }
      await ExecutionLog.write({
        'event': 'run_error',
        'conversationId': runConversation.id,
        'senderId': reply.senderId,
        'senderName': reply.sender.name,
        'runId': runId,
        'model': runConfig.model,
        'diagnostic': failureDiagnostic,
      }, apiKey: runConfig.apiKey);
      developer.log(
        '会话执行失败：${errorMessage(error)}',
        name: 'aurai.execution',
        error: error,
        stackTrace: stack,
      );
      if (runConversation.runState == ChatRunState.stopping ||
          error is AgentCancelled) {
        runConversation.runState = ChatRunState.cancelled;
        outcome = 'cancelled';
        executionWatch.stop();
        for (
          var i = runStepStart;
          i < runConversation.liveToolSteps.length;
          i++
        ) {
          final entry = runConversation.liveToolSteps[i];
          if (entry.step.status == AgentStepStatus.running) {
            runConversation.liveToolSteps[i] = (
              runId: entry.runId,
              afterMessageId: entry.afterMessageId,
              step: entry.step.copyWith(status: AgentStepStatus.cancelled),
            );
          }
        }
        unfinishedFinalMessageId = messages
            .where((message) => message.runId == runId)
            .lastOrNull
            ?.id;
        await _persistMember(runConversation, groupParent);
      } else {
        final connectionInterrupted = error is ModelConnectionInterrupted;
        runConversation.runState = connectionInterrupted
            ? ChatRunState.interrupted
            : ChatRunState.failed;
        if (connectionInterrupted) outcome = 'interrupted';
        runConversation.errorDetail = errorMessage(error);
        _recordRunError(error, (groupParent ?? runConversation).id);
        executionWatch.stop();
        for (
          var i = runStepStart;
          i < runConversation.liveToolSteps.length;
          i++
        ) {
          final entry = runConversation.liveToolSteps[i];
          if (entry.step.status == AgentStepStatus.running) {
            runConversation.liveToolSteps[i] = (
              runId: entry.runId,
              afterMessageId: entry.afterMessageId,
              step: entry.step.copyWith(status: AgentStepStatus.failed),
            );
          }
        }
        if (groupParent == null) {
          final answerIndex = messages.lastIndexWhere(
            (message) => message.runId == runId,
          );
          if (answerIndex >= 0) {
            unfinishedFinalMessageId = messages[answerIndex].id;
          }
          await _persistMember(runConversation, groupParent);
        }
      }
      rethrow;
    } finally {
      runConversation.isCompacting = false;
      executionWatch.stop();
      try {
        if (outcome != 'completed') {
          await _store.runs.finish(
            runId,
            outcome,
            executionWatch.elapsedMilliseconds,
            error: runConversation.errorDetail,
            diagnostic: failureDiagnostic,
            finalMessageId: unfinishedFinalMessageId,
            isTask: runConversation.hasExecutionProcess,
          );
        }
        if (sessionStarted && groupHistory == null && !alongsideGroup) {
          await _platform.endAgentSession(
            outcome,
            conversationId: runConversation.id,
            title: runConversation.title,
            reply: outcome == 'completed' && runMessageIds.isNotEmpty
                ? messages.lastWhere((m) => runMessageIds.contains(m.id)).text
                : '',
          );
        }
      } finally {
        if (groupParent != null &&
            outcome == 'completed' &&
            !leftSleepDraft &&
            sleepDraftRows.isNotEmpty) {
          await _store.database.delete(
            'app_state',
            where: 'key = ? AND value = ?',
            whereArgs: [sleepDraftKey, sleepDraft],
          );
        }
        if (groupParent == null) {
          _runtime = null;
        } else {
          _groupRuntimes.remove(reply.senderId);
        }
        _setMemberStreaming(reply.senderId, null, groupParent);
        _notifyMember(runConversation, groupParent);
        await _persistMember(runConversation, groupParent);
        await MessageCallbacks(
          _store.database,
        ).finish(callbackEvents, outcome == 'completed');
        if (htmlEvents.isNotEmpty) {
          await htmlGames.finishEvents(
            reply.senderId,
            htmlEvents.map((e) => e['id'] as String).toList(),
            success: outcome == 'completed',
          );
          for (final id
              in htmlEvents
                  .map((event) => event['message_id'] as String)
                  .toSet()) {
            HtmlGameSignals.changes.add(id);
          }
        }
        if (callbackEvents.isEmpty &&
            outcome == 'completed' &&
            (groupParent == null || runMessageIds.isNotEmpty)) {
          if (!runConversation.isTemporary)
            memory.learn(
              runConfig,
              runConversation.id,
              userMessage,
              memoryRevision,
            );
          if (groupHistory == null)
            completedReplies.value = ConversationCompletion(
              conversationId: runConversation.id,
              title: runConversation.title,
              runId: runId,
              reply: runMessageIds.isEmpty
                  ? ''
                  : messages
                        .lastWhere((m) => runMessageIds.contains(m.id))
                        .text,
            );
        }
      }
    }
  }
}
