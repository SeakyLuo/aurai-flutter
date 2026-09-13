part of 'chat_controller.dart';

extension ConversationRun on ChatController {
  Future<void> _executeConversation(
    Conversation runConversation, {
    bool scheduled = false,
  }) async {
    final messages = runConversation.messages;
    final steps = runConversation.steps;
    final reply = await _replyContext(runConversation);
    final runConfig = reply.config;
    final systemPrompt = reply.systemPrompt;
    final customInstructions = modelSettings.customInstructions;
    final responsePreferences = modelSettings.responsePreferences;
    final memoryRevision = memory.revision;
    await _persistRun(runConversation);
    final history = await _store.reader.messages(
      runConversation.id,
      forModel: true,
      modelConfig: runConfig,
      afterCheckpoint: runConversation.contextSummary?.throughMessageId,
    );
    final lastUser = history.lastIndexWhere(
      (message) => message.role == AgentMessageRole.user,
    );
    final executionWatch = Stopwatch()..start();
    runConversation.executionWatch = executionWatch;
    runConversation.restoredExecutionElapsed = Duration.zero;
    runConversation.hasExecutionProcess = false;
    runConversation.executionUserMessageId = history[lastUser].id;
    final runId = await _store.runs.start(
      runConversation.id,
      history[lastUser].id,
      runConfig,
      senderId: reply.senderId,
      systemPrompt: systemPrompt ?? agentSystemPrompt,
      customInstructions: customInstructions,
      responsePreferences: responsePreferences,
    );
    runConversation.activeRunId = runId;
    steps.clear();
    runConversation.liveToolSteps.clear();
    runConversation.errorDetail = null;
    runConversation.runState = ChatRunState.running;
    _deniedConfirmations.clear();
    _accessibilityDeclined = false;
    _notifyRun(runConversation);
    var sessionStarted = false;
    var outcome = 'failed';
    final activities = <AgentTaskActivity>[];
    try {
      await _persistRun(runConversation);
      await refreshCapabilities();
      if (runConversation.runState == ChatRunState.stopping)
        throw const AgentCancelled();
      final provider = switch (runConfig.service) {
        ModelService.openAi => OpenAiResponsesProvider(
          runConfig,
          systemPrompt: systemPrompt,
        ),
        ModelService.deepSeek => DeepSeekResponsesProvider(
          runConfig,
          systemPrompt: systemPrompt,
        ),
      };
      final webSources = WebSourceRegistry();
      final tools = <AgentTool>[
        AttachmentTool(history.expand((message) => message.files)),
        for (final operation in SkillTool.operations)
          SkillTool(skills, operation),
        RunSkillTool(skills, _platform, runConversation.id),
        WebTool('searchWeb', webSources),
        SourceDatesTool(webSources),
        ImageSearchTool(),
        WebTool('readWebPage', webSources),
        if (scheduledTasks.supported)
          for (final operation in ScheduleTaskTool.operations)
            ScheduleTaskTool(scheduledTasks, runConversation.id, operation),
        ...MemoryTools(
          memory,
          conversationId: runConversation.id,
          messageId: history[lastUser].id,
        ).tools,
        GetModelBalanceTool(modelSettings),
        OpenModelTopUpTool(modelSettings),
        AskUserTool(runConversation.id, (question) {
          pendingQuestion = question;
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
          if (question != null && sessionStarted) {
            unawaited(
              _platform.updateAgentSessionStep(
                question.isUserAction ? '等待你操作' : '等待你的回答',
              ),
            );
          }
          _notifyRun(runConversation);
        }),
        for (final name in LocalHistoryTool.names)
          LocalHistoryTool(_store.database.path, name),
        GetNetworkStateTool(_platform),
        GetNetworkEventsTool(_platform),
        DnsLookupTool(_platform),
        TlsProbeTool(_platform),
        HttpProbeTool(_platform),
        GetNotificationsTool(_platform, runConfig.service.label),
        SendNotificationTool(_platform, runConversation.id),
        InspectAndroidApiTool(_platform),
        ExecuteAndroidScriptTool(_platform, runConversation.id),
        ObserveDeviceTool(_platform),
        CaptureScreenTool(_platform, runConfig.service.label),
        TapScreenTool(_platform, runConfig.service.label),
        WaitTool(),
        WaitForUiTool(_platform),
        RequestAccessibilityAccessTool(_requestAccessibility),
        for (final name in uiToolActions.keys)
          ActTool(_platform, runConfig.service.label, name),
        FindAppsTool(_platform),
        LaunchAppTool(_platform),
        StartIntentTool(_platform),
        OpenSettingsTool(_platform),
        AppShellTool(_platform),
        for (final name in DocumentTool.names) DocumentTool(_platform, name),
        for (final name in DeviceExtensionTool.names)
          DeviceExtensionTool(_platform, name),
      ];
      final registry = ToolRegistry(tools: tools, capabilities: capabilities);
      registry.load(
        await recentConversationTools(_store.database, runConversation.id),
      );
      final executor = ToolExecutor(registry: registry, confirm: _confirm);
      _runtime = AgentRuntime(
        provider: provider,
        registry: registry,
        executor: executor,
      );
      if (scheduled) {
        await _platform.startAgentSession('正在执行定时任务');
        sessionStarted = true;
      }
      if (runConversation.runState == ChatRunState.stopping)
        throw const AgentCancelled();
      var turnOrdinal = 0;
      late String modelTurnId;
      final runMessageIds = <String>[];
      final stepActivityIndices = <int>[];
      String? turnMessageId;
      int? turnActivityIndex;
      int? outputMessageIndex;
      await _runtime!.run(
        conversation: List.unmodifiable(history.take(lastUser + 1)),
        contextSummary: runConversation.contextSummary,
        personalContext: () => [
          responsePreferences.instructions,
          if (customInstructions.isNotEmpty) '用户自定义指令：\n$customInstructions',
          memory.context,
        ].join('\n\n'),
        onContextSummary: (summary) async {
          runConversation.contextSummary = summary;
          await _persistRun(runConversation);
        },
        onTurnStarted: () async {
          modelTurnId = await _store.runs.startTurn(
            runConversation.id,
            runId,
            turnOrdinal++,
          );
          turnMessageId = null;
          turnActivityIndex = null;
          outputMessageIndex = null;
          streamingMessageId = null;
          _notifyRun(runConversation);
        },
        onTurnCompleted: (turn) async {
          await _persistRun(runConversation);
          await _store.runs.finishTurn(modelTurnId, turn);
        },
        onToolStarted: (call) async {
          if (!sessionStarted) {
            await _platform.startAgentSession(toolTitle(call.name));
            sessionStarted = true;
          }
          await _store.runs.startTool(
            runConversation.id,
            runId,
            modelTurnId,
            call,
          );
        },
        onToolCompleted: (result) => _store.runs.finishTool(runId, result),
        onReconnect: (attempt) {
          if (runConversation.reconnectAttempt == attempt) return;
          runConversation.reconnectAttempt = attempt;
          _notifyRun(runConversation);
        },
        onMessageStarted: (index) {
          if (outputMessageIndex == index) return;
          outputMessageIndex = index;
          turnMessageId = null;
          turnActivityIndex = null;
        },
        onProcessingStarted: () {
          if (runConversation.hasExecutionProcess) return;
          runConversation.hasExecutionProcess = true;
          _notifyRun(runConversation);
        },
        onTextChanged: (text) {
          if (text.isEmpty) return;
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
                runId: runId,
                modelTurnId: modelTurnId,
                text: text,
                createdAt: DateTime.now(),
              ),
            );
            runConversation.messageCount++;
          } else {
            final previous = messages.last;
            messages[messages.length - 1] = AgentMessage(
              id: previous.id,
              role: previous.role,
              senderId: previous.senderId,
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
          streamingMessageId = turnMessageId;
          _notifyRun(runConversation);
        },
        onStepsChanged: (newSteps) {
          final liveSteps = runConversation.liveToolSteps;
          for (var i = 0; i < newSteps.length; i++) {
            final step = newSteps[i];
            if (i < liveSteps.length && identical(liveSteps[i].step, step))
              continue;
            if (i == liveSteps.length) {
              liveSteps.add((afterMessageId: messages.last.id, step: step));
            } else {
              liveSteps[i] = (
                afterMessageId: liveSteps[i].afterMessageId,
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
          streamingMessageId = null;
          steps
            ..clear()
            ..addAll(newSteps);
          final runningStep = newSteps.where(
            (step) => step.status == AgentStepStatus.running,
          );
          if (sessionStarted)
            unawaited(
              _platform.updateAgentSessionStep(
                runningStep.isEmpty ? '正在分析结果' : runningStep.last.title,
              ),
            );
          _notifyRun(runConversation);
        },
      );
      executionWatch.stop();
      if (runConversation.hasExecutionProcess) {
        final answer = messages.last;
        messages[messages.length - 1] = AgentMessage(
          id: answer.id,
          role: answer.role,
          senderId: answer.senderId,
          runId: answer.runId,
          modelTurnId: answer.modelTurnId,
          text: answer.text,
          createdAt: answer.createdAt,
          images: answer.images,
          taskSummary: AgentTaskSummary(
            elapsedMilliseconds: executionWatch.elapsedMilliseconds,
            intermediateMessageIds: List.unmodifiable(
              runMessageIds.take(runMessageIds.length - 1),
            ),
            activities: List.unmodifiable(activities.take(turnActivityIndex!)),
          ),
        );
      }
      await _persistRun(runConversation);
      await _store.runs.finish(
        runId,
        'completed',
        executionWatch.elapsedMilliseconds,
        finalMessageId: messages.last.id,
        isTask: runConversation.hasExecutionProcess,
      );
      runConversation.liveToolSteps.clear();
      runConversation.pendingGoal = null;
      runConversation.runState = ChatRunState.idle;
      outcome = 'completed';
    } on Object catch (error) {
      if (runConversation.runState == ChatRunState.stopping ||
          error is AgentCancelled) {
        runConversation.runState = ChatRunState.cancelled;
        outcome = 'cancelled';
        executionWatch.stop();
        if (messages.last.runId != runId) {
          messages.add(
            AgentMessage(
              id: newMessageId(),
              role: AgentMessageRole.assistant,
              senderId: reply.senderId,
              text: '',
              runId: runId,
              createdAt: DateTime.now(),
            ),
          );
          runConversation.messageCount++;
        }
        final last = messages.last;
        messages[messages.length - 1] = AgentMessage(
          id: last.id,
          role: last.role,
          senderId: last.senderId,
          text: last.text,
          runId: last.runId,
          modelTurnId: last.modelTurnId,
          createdAt: last.createdAt,
          taskSummary: !runConversation.hasExecutionProcess
              ? null
              : AgentTaskSummary(
                  elapsedMilliseconds: executionWatch.elapsedMilliseconds,
                  stopped: true,
                  intermediateMessageIds: [
                    for (final message in messages)
                      if (message.runId == runId && message.id != last.id)
                        message.id,
                  ],
                  activities: [
                    for (final activity in activities)
                      AgentTaskActivity(
                        text: activity.text,
                        messageId: activity.messageId,
                        toolName: activity.toolName,
                        requestJson: activity.requestJson,
                        resultJson: activity.resultJson,
                        status: activity.status == AgentStepStatus.running
                            ? AgentStepStatus.cancelled
                            : activity.status,
                      ),
                  ],
                ),
        );
        runConversation.liveToolSteps.clear();
        await _persistRun(runConversation);
      } else {
        runConversation.runState = ChatRunState.failed;
        runConversation.errorDetail = switch (error) {
          ModelProviderException() => error.message,
          PlatformException() => error.message ?? '设备能力调用失败',
          _ => '任务执行失败',
        };
      }
      rethrow;
    } finally {
      executionWatch.stop();
      try {
        if (outcome != 'completed') {
          await _store.runs.finish(
            runId,
            outcome,
            executionWatch.elapsedMilliseconds,
            error: runConversation.errorDetail,
            finalMessageId: outcome == 'cancelled' ? messages.last.id : null,
            isTask: runConversation.hasExecutionProcess,
          );
        }
        if (sessionStarted) {
          await _platform.endAgentSession(
            outcome,
            conversationId: runConversation.id,
            title: runConversation.title,
            reply: outcome == 'completed' ? messages.last.text : '',
          );
        }
      } finally {
        _runtime = null;
        streamingMessageId = null;
        _notifyRun(runConversation);
        await _persistRun(runConversation);
        if (outcome == 'completed') {
          memory.learn(
            runConfig,
            runConversation.id,
            history[lastUser],
            memoryRevision,
          );
          completedReplies.value = ConversationCompletion(
            conversationId: runConversation.id,
            title: runConversation.title,
            runId: runId,
            reply: messages.last.text,
          );
        }
      }
    }
  }

  Future<void> _persistRun(Conversation conversation) =>
      _store.writer.save(conversation, makeActive: false);

  void _notifyRun(Conversation conversation) {
    _updateConversationList(conversation);
    _conversationChanged();
  }
}
