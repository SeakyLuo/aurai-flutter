part of 'chat_controller.dart';

extension ConversationRun on ChatController {
  Future<void> _executeConversation(Conversation runConversation) async {
    final messages = runConversation.messages;
    final steps = runConversation.steps;
    final runConfig = config;
    final systemPrompt = modelSettings.systemPrompt;
    final memoryRevision = memory.revision;
    await _persistRun(runConversation);
    final history = await _store.reader.messages(
      runConversation.id,
      forModel: true,
      afterCheckpoint: runConversation.contextSummary?.throughMessageId,
    );
    final lastUser = history.lastIndexWhere(
      (message) => message.role == AgentMessageRole.user,
    );
    final executionWatch = Stopwatch()..start();
    final runId = await _store.runs.start(
      runConversation.id,
      history[lastUser].id,
      runConfig,
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
      final tools = <AgentTool>[
        ManageSkillTool(skills),
        RunSkillTool(skills, _platform, runConversation.id),
        WebTool('searchWeb'),
        WebTool('readWebPage'),
        if (scheduledTasks.supported)
          for (final operation in ScheduleTaskTool.operations)
            ScheduleTaskTool(scheduledTasks, runConversation.id, operation),
        ...MemoryTools(memory).tools,
        GetModelBalanceTool(modelSettings),
        OpenModelTopUpTool(modelSettings),
        AskUserTool(runConversation.id, (question) {
          pendingQuestion = question;
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
        RequestAccessibilityAccessTool(_requestAccessibility),
        for (final name in uiToolActions.keys)
          ActTool(_platform, runConfig.service.label, name),
        FindAppsTool(_platform),
        LaunchAppTool(_platform),
        StartIntentTool(_platform),
        OpenSettingsTool(_platform),
        AppShellTool(_platform),
      ];
      final registry = ToolRegistry(tools: tools, capabilities: capabilities);
      final executor = ToolExecutor(registry: registry, confirm: _confirm);
      _runtime = AgentRuntime(
        provider: provider,
        registry: registry,
        executor: executor,
      );
      await _platform.startAgentSession();
      sessionStarted = true;
      if (runConversation.runState == ChatRunState.stopping)
        throw const AgentCancelled();
      var turnOrdinal = 0;
      late String modelTurnId;
      final runMessageIds = <String>[];
      final stepActivityIndices = <int>[];
      String? turnMessageId;
      int? turnActivityIndex;
      await _runtime!.run(
        conversation: List.unmodifiable(history.take(lastUser + 1)),
        contextSummary: runConversation.contextSummary,
        personalContext: () => memory.context,
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
          streamingMessageId = null;
          _notifyRun(runConversation);
        },
        onTurnCompleted: (turn) async {
          await _persistRun(runConversation);
          await _store.runs.finishTurn(modelTurnId, turn.continuationToken);
        },
        onToolStarted: (call) =>
            _store.runs.startTool(runConversation.id, runId, modelTurnId, call),
        onToolCompleted: (result) => _store.runs.finishTool(runId, result),
        onTextChanged: (text) {
          if (text.isEmpty) return;
          if (turnMessageId == null) {
            turnMessageId = newMessageId();
            runMessageIds.add(turnMessageId!);
            turnActivityIndex = activities.length;
            activities.add(AgentTaskActivity(text: text));
            messages.add(
              AgentMessage(
                id: turnMessageId!,
                role: AgentMessageRole.assistant,
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
              runId: previous.runId,
              modelTurnId: previous.modelTurnId,
              text: text,
              createdAt: previous.createdAt,
            );
          }
          activities[turnActivityIndex!] = AgentTaskActivity(text: text);
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
          unawaited(
            _platform.updateAgentSessionStep(
              runningStep.isEmpty ? '正在分析结果' : runningStep.last.title,
            ),
          );
          _notifyRun(runConversation);
        },
      );
      executionWatch.stop();
      if (steps.isNotEmpty) {
        final answer = messages.last;
        messages[messages.length - 1] = AgentMessage(
          id: answer.id,
          role: answer.role,
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
        isTask: steps.isNotEmpty,
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
          text: last.text,
          runId: last.runId,
          modelTurnId: last.modelTurnId,
          createdAt: last.createdAt,
          taskSummary: AgentTaskSummary(
            elapsedMilliseconds: executionWatch.elapsedMilliseconds,
            stopped: true,
            intermediateMessageIds: [
              for (final message in messages)
                if (message.runId == runId && message.id != last.id) message.id,
            ],
            activities: [
              for (final activity in activities)
                AgentTaskActivity(
                  text: activity.text,
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
            isTask: outcome == 'cancelled',
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
