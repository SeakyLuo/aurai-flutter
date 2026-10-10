part of 'chat_controller.dart';

extension ConversationRun on ChatController {
  Future<void> _executeMember(
    Conversation runConversation, {
    bool scheduled = false,
    bool callbacksOnly = false,
    required ExecutionReplyContext reply,
    List<AgentMessage>? groupHistory,
    AgentMessage? groupUser,
    Conversation? groupParent,
    String? continuationRunId,
    String? sleepWakeReason,
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
    if (groupParent == null && sleepWakeReason == null) {
      await _resumePrivateReply(runConversation, reply.senderId);
    }
    final sleepDraft = await _groupSleepDraft(sleepDraftKey);
    var leftSleepDraft = false;
    final systemPrompt = await _memberSystemPrompt(
      reply,
      group: groupParent != null,
    );
    final memoryContext = await _conversationMemory(
      summaryOwner,
      reply.profile,
      privateScope: groupHistory == null ? '' : runConversation.id,
    );
    final (:project, :memory, privateMemory: sharedProjectMemory) =
        memoryContext;
    final skills = await aiSkills(reply.senderId);
    final documents = await _aiDocuments(reply.senderId, project);
    final customInstructions = reply.profile.preferences.customInstructions;
    final responsePreferences = reply.profile.preferences.responses;
    final callbackEvents = await MessageCallbacks(
      _store.database,
    ).pending(runConversation.id, reply.senderId);
    if (callbacksOnly && callbackEvents.isEmpty) return;
    await _persistMember(runConversation, groupParent);
    final history =
        groupHistory ?? await _loadPrivateRunHistory(runConversation, reply);
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
    final continuationProtocol = await _runContinuation(
      conversation: runConversation,
      reply: reply,
      userMessage: userMessage,
      direct: groupParent == null,
      hasCallbacks: callbackEvents.isNotEmpty,
      runId: continuationRunId,
      sleepWakeReason: sleepWakeReason,
    );
    final executionWatch = Stopwatch()..start();
    runConversation.executionWatch = executionWatch;
    runConversation.restoredExecutionElapsed = Duration.zero;
    runConversation.hasExecutionProcess = continuationProtocol.isNotEmpty;
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
    final gitSnapshots = ProjectRunSnapshots(_platform, _store.database, runId);
    if (project != null) await gitSnapshots.begin(project.directories);
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
      final provider = runConfig.service.useOpenAiTransport
          ? OpenAiResponsesProvider(
              runConfig,
              systemPrompt: systemPrompt,
              sharedContext: (groupParent ?? runConversation).sharedContext,
            )
          : DeepSeekResponsesProvider(
              runConfig,
              systemPrompt: systemPrompt,
              sharedContext: (groupParent ?? runConversation).sharedContext,
            );
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
        onProjectGitBaseChanged: gitSnapshots.rebaseAfterGitBaseChange,
        groupId: groupHistory == null ? null : runConversation.id,
        questionTool: AskUserTool(
          runConversation.id,
          (question) => _showRunQuestion(
            runConversation,
            groupParent,
            reply,
            runId,
            question,
            showProgress:
                sessionStarted && groupHistory == null && !alongsideGroup,
          ),
          sender: reply.sender,
          executionRunId: runId,
          onWaiting: (call, sent) => _store.runs.finishTool(
            runId,
            ToolResult(
              callId: call.id,
              toolName: call.name,
              status: ToolResultStatus.success,
              output: {...sent, 'pending': true},
            ),
          ),
        ),
      )..addAll(_thinkingTools(runConversation, groupParent, reply));
      tools.add(
        runConversation.isPersonalChat
            ? RunTaskTool(
                (call, cancelled) => _prepareTask(
                  call,
                  cancelled,
                  source: runConversation,
                  reply: reply,
                  sourceMessageId:
                      callbackEvents.lastOrNull?['message_id'] as String? ??
                      userMessage.id,
                ),
                onError: (error) => _recordRunError(error, summaryOwner.id),
              )
            : RunSubagentTool(
                (call, cancelled) => _prepareSubagent(
                  call,
                  cancelled,
                  parentRunId: runId,
                  reply: reply,
                  conversation: runConversation,
                  parent: groupParent,
                  memory: memory,
                  skills: skills,
                  documents: documents,
                  history: observed,
                  systemPrompt: systemPrompt,
                  customInstructions: customInstructions,
                ),
                onError: (error) => _recordRunError(error, summaryOwner.id),
              ),
      );
      final registry = await _createMemberToolRegistry(
        currentProjectId: () => documents.project?.id,
        tools: tools,
        parent: groupParent,
        member: runConversation,
        reply: reply,
        observed: observed,
        publishedIds: runMessageIds,
        onSleep: () => leftSleepDraft = true,
        groupId: groupHistory == null ? null : runConversation.id,
      );
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
        userInputs: groupParent == null ? _execution.userInputs : null,
      );
      if (groupParent == null) {
        _runtime = runtime;
      } else {
        _groupRuntimes[reply.senderId] = runtime;
      }
      if (runConversation.runState == ChatRunState.stopping)
        throw AgentCancelled();
      final decision =
          groupParent != null &&
              callbackEvents.isEmpty &&
              continuationRunId == null
          ? await _interactiveAiDecision(
              userMessage,
              groupParent,
              reply.senderId,
            )
          : null;
      var turnOrdinal = 0;
      late String modelTurnId;
      final stepActivityIndices = <int>[];
      String? turnMessageId;
      int? turnActivityIndex;
      String? reasoningMessageId;
      int? reasoningActivityIndex, outputMessageIndex;
      await runtime.run(
        streamOutput: groupParent != null,
        decision: decision,
        runtimeInput: _programInput(
          summaryOwner,
          reply.senderId,
          observed,
          userMessage,
        ),
        endsRun: (result) => _endsRestRun(result, () => leftSleepDraft = true),
        conversation: [
          ...(groupHistory == null
              ? _privateHistory(
                  sleepWakeReason != null
                      ? history
                      : history.take(lastUser + 1),
                  reply.senderId,
                )
              : _groupHistory(
                  [...history],
                  reply.senderId,
                  decisionMessageId: decision == null ? null : userMessage.id,
                )),
          if (callbackEvents.isNotEmpty) _callbackContext(callbackEvents),
          if (sleepWakeReason != null)
            _sleepWakeMessage(runId, sleepWakeReason),
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
        privateContextSummary:
            groupParent?.privateContextSummaries[reply.senderId],
        organizeTask: () => memory.organizeTask(runId),
        cancelOrganization: () => memory.cancelTaskOrganization(runId),
        personalContext: () async => [
          if (runConversation.isPersonalChat)
            '当前是你与用户的长期私聊，同一个联系人始终使用这段聊天。用户可以在这里闲聊或交代事情，按具体请求行动；已有任务是独立的工作记录。',
          await _taskContext(runConversation),
          responsePreferences.instructions,
          runConversation.isPersonalChat
              ? RunTaskTool.instructions
              : RunSubagentTool.instructions,
          if (sleepDraft.isNotEmpty)
            '你上次休眠前留下的私人草稿（尚未发送）：\n$sleepDraft\n请结合最新消息决定保留、改写或放弃；不要自动发送，也不要当作用户的新指令。',
          if (customInstructions.isNotEmpty) '用户自定义指令：\n$customInstructions',
          if (runConversation.usesPersonalization)
            await memory.sharedContext(query: userMessage.text),
          if (runConversation.usesPersonalization &&
              sharedProjectMemory != null)
            await sharedProjectMemory.sharedContext(query: userMessage.text),
          if (runConversation.isTemporary) '当前为临时会话，不得将本次内容写入长期记忆。',
          if (project != null) _projectContext(project),
          if (alongsideGroup) '群聊正在后台进行；当前私聊仍可使用完整工具集。共享手机界面和用户交互由执行器互斥协调。',
          if (groupParent != null) '当前群成员：${jsonEncode((awaitedRoster))}',
          if (groupParent != null)
            await GroupNoticeTool(
              groupStore,
              reply.senderId,
              groupParent.id,
            ).context(),
        ].join('\n\n'),
        onContextSummary: (summary) =>
            _saveRunContextSummary(summaryOwner, summary, historyVersion),
        onPrivateContextSummary: groupParent == null
            ? null
            : (summary) => _saveRunContextSummary(
                groupParent,
                summary,
                historyVersion,
                senderId: reply.senderId,
              ),
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
          _notifyMember(runConversation, groupParent, activityOnly: true);
        },
        takeUserUpdates: groupParent == null
            ? null
            : () => _takeGroupRunUpdates(reply.senderId, observed),
        onTurnCompleted: (turn) async {
          _setMemberStreaming(reply.senderId, null, groupParent);
          _notifyMember(runConversation, groupParent, activityOnly: true);
          await _persistMember(runConversation, groupParent);
          await _store.runs.finishTurn(modelTurnId, turn);
          if (groupParent != null && !runConversation.isTemporary)
            await memory.captureObserved(
              runId,
              observed.reversed
                  .where((m) => m.canView(reply.senderId))
                  .take(24)
                  .map((m) => m.id),
            );
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
        onToolCompleted: _runToolCompletionListener(
          runConversation,
          reply,
          runConfig,
          runId,
          gitSnapshots,
          diagnosticCalls,
        ),
        onReconnect: (attempt) {
          if (runConversation.reconnectAttempt == attempt) return;
          runConversation.reconnectAttempt = attempt;
          _notifyMember(runConversation, groupParent, activityOnly: true);
        },
        onMessageStarted: (index) {
          if (outputMessageIndex == index) return;
          outputMessageIndex = index;
          turnMessageId = null;
          turnActivityIndex = null;
        },
        onMessageCompleted: (_) {
          _setMemberStreaming(reply.senderId, null, groupParent);
          _notifyMember(runConversation, groupParent, activityOnly: true);
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
          if (runConversation.isPersonalChat) {
            privateThoughtChanges.value++;
          } else {
            _notifyMember(runConversation, groupParent);
          }
        },
        onTextChanged: (text) {
          if (groupParent != null && text.trim().isNotEmpty) {
            _recordGroupThought(
              reply.senderId,
              runId,
              turnOrdinal,
              text,
              isReasoning: false,
              messageIndex: outputMessageIndex ?? 0,
            );
          }
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
                markdown: true,
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
              markdown: true,
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
            _recordGroupSteps(reply.senderId, runId, newSteps);
          }
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
              startedAt: step.startedAt,
              finishedAt: step.finishedAt,
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
          _notifyMember(runConversation, groupParent, activityOnly: true);
        },
      );
      for (final message in messages.where(
        (m) =>
            m.runId == runId && (m.interactive != null || m.htmlGame != null),
      )) {
        if (!runMessageIds.contains(message.id)) runMessageIds.add(message.id);
      }
      executionWatch.stop();
      final completedGitChanges = await gitSnapshots.finish();
      _attachRunSummary(
        runConversation,
        groupParent,
        messages,
        runMessageIds,
        activities,
        executionWatch,
        completedGitChanges,
      );
      await _persistMember(runConversation, groupParent);
      await _store.runs.finish(
        runId,
        'completed',
        executionWatch.elapsedMilliseconds,
        keepPendingGoal: _execution.queuedUserMessageId != null,
        finalMessageId: runMessageIds.isEmpty
            ? null
            : messages.lastWhere((m) => runMessageIds.contains(m.id)).id,
        isTask: runConversation.isTask && runConversation.hasExecutionProcess,
      );
      if (groupHistory == null && _execution.queuedUserMessageId == null)
        runConversation.pendingGoal = null;
      if (runConversation.runState != ChatRunState.stopping) {
        runConversation.runState = ChatRunState.idle;
      }
      outcome = 'completed';
    } on Object catch (error, stack) {
      if (error is! AgentCancelled) {
        failureDiagnostic = await _logRunFailure(
          error,
          stack,
          config: runConfig,
          conversationId: runConversation.id,
          sender: reply.sender,
          runId: runId,
        );
      }
      if (runConversation.runState == ChatRunState.stopping ||
          error is AgentCancelled) {
        _recordRunError(error, (groupParent ?? runConversation).id);
        runConversation.runState = ChatRunState.cancelled;
        outcome = 'cancelled';
        executionWatch.stop();
        runConversation.unfinishedRunElapsed[runId] = executionWatch.elapsed;
        runConversation.cancelledRunMessages[runId] =
            callbackEvents.lastOrNull?['message_id'] as String? ??
            userMessage.id;
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
        runConversation.unfinishedRunElapsed[runId] = executionWatch.elapsed;
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
          _appendPrivateRunFailure(runConversation, reply.sender, runId);
          final answerIndex = messages.lastIndexWhere(
            (message) => message.runId == runId,
          );
          if (answerIndex >= 0) {
            unfinishedFinalMessageId = messages[answerIndex].id;
          }
          _attachRunSummary(
            runConversation,
            groupParent,
            messages,
            runMessageIds,
            activities,
            executionWatch,
            null,
          );
          await _persistMember(runConversation, groupParent);
        }
      }
      rethrow;
    } finally {
      runConversation.isCompacting = false;
      executionWatch.stop();
      final notificationMessage = messages
          .where(
            (message) =>
                runMessageIds.contains(message.id) &&
                !message.isReasoning &&
                !message.isSystem &&
                message.canView(MessageSender.localUser.id),
          )
          .lastOrNull;
      final notificationReply = notificationMessage == null
          ? ''
          : MessageSummary.fromMessage(notificationMessage);
      try {
        if (outcome != 'completed') {
          await _store.runs.finish(
            runId,
            outcome,
            executionWatch.elapsedMilliseconds,
            error: runConversation.errorDetail,
            diagnostic: failureDiagnostic,
            finalMessageId: unfinishedFinalMessageId,
            isTask:
                runConversation.isTask && runConversation.hasExecutionProcess,
          );
        }
        if (sessionStarted && groupHistory == null && !alongsideGroup) {
          await _platform.endAgentSession(
            outcome,
            conversationId: runConversation.id,
            title: runConversation.title,
            reply: outcome == 'completed' ? notificationReply : '',
          );
        }
      } finally {
        await _finishLiveProjectChanges(gitSnapshots, runId);
        if (outcome == 'completed' &&
            !leftSleepDraft &&
            sleepDraft.isNotEmpty) {
          await _consumeSleepDraft(sleepDraftKey, sleepDraft);
        }
        _execution.programRuns.remove(reply.senderId);
        if (groupParent == null) {
          _runtime = null;
          _execution.liveUserMessageIds.clear();
        } else {
          _groupRuntimes.remove(reply.senderId);
        }
        _setMemberStreaming(reply.senderId, null, groupParent);
        _notifyMember(runConversation, groupParent);
        await _persistMember(runConversation, groupParent);
        await MessageCallbacks(
          _store.database,
        ).finish(callbackEvents, outcome == 'completed');
        if (callbackEvents.isEmpty &&
            outcome == 'completed' &&
            notificationReply.trim().isNotEmpty) {
          if (groupHistory == null)
            completedReplies.value = ConversationCompletion(
              conversationId: runConversation.id,
              title: runConversation.title,
              runId: runId,
              reply: notificationReply,
            );
        }
      }
    }
  }
}
