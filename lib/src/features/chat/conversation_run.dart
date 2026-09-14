part of 'chat_controller.dart';

extension ConversationRun on ChatController {
  Future<void> _executeMember(
    Conversation runConversation, {
    bool scheduled = false,
    required _ReplyContext reply,
    List<AgentMessage>? groupHistory,
    AgentMessage? groupUser,
    Conversation? groupParent,
  }) async {
    final alongsideGroup = identical(runConversation, _privateConversation);
    final messages = runConversation.messages;
    final steps = runConversation.steps;
    final runConfig = reply.config;
    final systemPrompt = reply.systemPrompt;
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
    final userMessage = groupUser ?? history[lastUser];
    final executionWatch = Stopwatch()..start();
    runConversation.executionWatch = executionWatch;
    runConversation.restoredExecutionElapsed = Duration.zero;
    runConversation.hasExecutionProcess = false;
    runConversation.executionUserMessageId = userMessage.id;
    final runId = await _store.runs.start(
      runConversation.id,
      userMessage.id,
      runConfig,
      senderId: reply.senderId,
      group: groupParent != null,
      systemPrompt: systemPrompt ?? agentSystemPrompt,
      customInstructions: customInstructions,
      responsePreferences: responsePreferences,
    );
    runConversation.activeRunId = runId;
    steps.clear();
    runConversation.liveToolSteps.clear();
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
    final activities = <AgentTaskActivity>[];
    final runMessageIds = <String>[];
    final observed = List<AgentMessage>.of(history);
    final awaitedRoster = _groupSenders.values
        .map((m) => {'id': m.id, 'name': m.name})
        .toList();
    try {
      await _persistMember(runConversation, groupParent);
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
      final tools = _createTools(
        conversation: groupParent ?? runConversation,
        senderId: reply.senderId,
        messageId: userMessage.id,
        providerLabel: runConfig.service.label,
        memory: memory,
        skills: skills,
        documents: documents,
        history: observed,
        webSources: webSources,
        groupId: groupHistory == null ? null : runConversation.id,
        questionTool: AskUserTool(runConversation.id, (question) {
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
          _notifyMember(runConversation, groupParent);
        }),
      );
      if (groupParent != null) {
        tools.removeWhere((t) => t.definition.name == 'sendGroupMessages');
        tools.add(
          GroupMessageTool(
            (arguments) => _deliverGroupMessages(
              arguments: arguments,
              member: runConversation,
              parent: groupParent,
              reply: reply,
              observed: observed,
              publishedIds: runMessageIds,
            ),
          ),
        );
      }
      if (alongsideGroup) {
        tools.retainWhere(
          (tool) => {
            ...AppControlTool.descriptions.keys,
            'sendGroupMessages',
            'readMyProfile',
            'updateMyProfile',
            'listGroupChats',
            'readGroupChat',
            'readAttachment',
          }.contains(tool.definition.name),
        );
      }
      final registry = ToolRegistry(tools: tools, capabilities: capabilities);
      registry.load(
        await recentConversationTools(_store.database, runConversation.id),
      );
      registry.load(['sendGroupMessages']);
      Future<bool> confirm(ToolCall call, ToolDefinition definition) =>
          _confirm(
            call,
            definition,
            runId: runId,
            senderId: reply.senderId,
            screenAccess: reply.profile.preferences.screenAccess,
          );
      final executor = groupParent == null
          ? ToolExecutor(registry: registry, confirm: confirm)
          : GroupToolExecutor(
              registry: registry,
              confirm: confirm,
              queue: _groupToolQueue,
              waitForInteraction: () async {
                await pendingQuestion?.result.future;
              },
              cancelled: () =>
                  groupParent.runState == ChatRunState.stopping ||
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
      if (scheduled) {
        await _platform.startAgentSession('正在执行定时任务');
        sessionStarted = true;
      }
      if (runConversation.runState == ChatRunState.stopping)
        throw const AgentCancelled();
      var turnOrdinal = 0;
      late String modelTurnId;

      var silenceRequested = false;
      final stepActivityIndices = <int>[];
      String? turnMessageId;
      int? turnActivityIndex;
      int? outputMessageIndex;
      await runtime.run(
        conversation: groupHistory == null
            ? List.unmodifiable(history.take(lastUser + 1))
            : _groupHistory(history, reply.senderId),
        contextSummary: groupHistory == null
            ? runConversation.contextSummary
            : null,
        personalContext: () => [
          responsePreferences.instructions,
          if (customInstructions.isNotEmpty) '用户自定义指令：\n$customInstructions',
          memory.context,
          if (alongsideGroup) '群聊正在后台进行。这里可以私聊以及调整自己的群聊接话状态；设备操作需等共享执行任务结束。',
          if (groupParent != null) '当前群成员：${jsonEncode((awaitedRoster))}',
        ].join('\n\n'),
        onContextSummary: (summary) async {
          if (groupHistory != null) return;
          runConversation.contextSummary = summary;
          await _persistMember(runConversation, groupParent);
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
          _setMemberStreaming(reply.senderId, null, groupParent);
          _notifyMember(runConversation, groupParent);
        },
        onTurnCompleted: (turn) async {
          await _persistMember(runConversation, groupParent);
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
        onTextChanged: (text) {
          if (groupParent != null) {
            silenceRequested = true;
            return;
          }
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
                sender: reply.sender,
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
                .where((s) => s.toolName != 'sendGroupMessages')
                .toList();
          }
          if (groupParent != null && newSteps.isNotEmpty) {
            runConversation.hasExecutionProcess = true;
          }
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
          _setMemberStreaming(reply.senderId, null, groupParent);
          steps
            ..clear()
            ..addAll(newSteps);
          final runningStep = newSteps.where(
            (step) => step.status == AgentStepStatus.running,
          );
          if (sessionStarted && !alongsideGroup)
            unawaited(
              _platform.updateAgentSessionStep(
                runningStep.isEmpty ? '正在分析结果' : runningStep.last.title,
              ),
            );
          _notifyMember(runConversation, groupParent);
        },
      );
      executionWatch.stop();
      if (groupParent == null && runMessageIds.isEmpty && !silenceRequested)
        throw StateError('模型未返回回复，请重试');
      if (runMessageIds.isNotEmpty && runConversation.hasExecutionProcess) {
        final answer = messages.last;
        messages[messages.length - 1] = AgentMessage(
          id: answer.id,
          role: answer.role,
          isGroupMessage: answer.isGroupMessage,
          senderId: answer.senderId,
          sender: answer.sender,
          runId: answer.runId,
          modelTurnId: answer.modelTurnId,
          text: answer.text,
          createdAt: answer.createdAt,
          images: answer.images,
          quote: answer.quote,
          taskSummary: AgentTaskSummary(
            elapsedMilliseconds: executionWatch.elapsedMilliseconds,
            intermediateMessageIds: List.unmodifiable(
              groupParent == null
                  ? runMessageIds.take(runMessageIds.length - 1)
                  : const <String>[],
            ),
            activities: List.unmodifiable(
              groupParent != null
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
        finalMessageId: runMessageIds.isEmpty ? null : messages.last.id,
        isTask: runConversation.hasExecutionProcess,
      );
      runConversation.liveToolSteps.clear();
      if (groupHistory == null) runConversation.pendingGoal = null;
      if (runConversation.runState != ChatRunState.stopping) {
        runConversation.runState = ChatRunState.idle;
      }
      outcome = 'completed';
    } on Object catch (error) {
      if (runConversation.runState == ChatRunState.stopping ||
          error is AgentCancelled) {
        runConversation.runState = ChatRunState.cancelled;
        outcome = 'cancelled';
        executionWatch.stop();
        final keepActivity =
            groupParent == null ||
            messages.last.runId == runId ||
            activities.any((activity) => activity.toolName != null);
        if (keepActivity) {
          if (messages.last.runId != runId) {
            messages.add(
              AgentMessage(
                id: newMessageId(),
                role: AgentMessageRole.assistant,
                senderId: reply.senderId,
                sender: reply.sender,
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
            isGroupMessage: last.isGroupMessage,
            quote: last.quote,
            senderId: last.senderId,
            sender: last.sender,
            text: last.text,
            images: last.images,
            files: last.files,
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
        }
        runConversation.liveToolSteps.clear();
        await _persistMember(runConversation, groupParent);
      } else {
        runConversation.runState = ChatRunState.failed;
        runConversation.errorDetail = switch (error) {
          StateError() => error.message,
          ModelProviderException() => error.displayMessage,
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
            finalMessageId:
                outcome == 'cancelled' && messages.last.runId == runId
                ? messages.last.id
                : null,
            isTask: runConversation.hasExecutionProcess,
          );
        }
        if (sessionStarted && groupHistory == null && !alongsideGroup) {
          await _platform.endAgentSession(
            outcome,
            conversationId: runConversation.id,
            title: runConversation.title,
            reply: outcome == 'completed' ? messages.last.text : '',
          );
        }
      } finally {
        if (groupParent == null) {
          _runtime = null;
        } else {
          _groupRuntimes.remove(reply.senderId);
        }
        _setMemberStreaming(reply.senderId, null, groupParent);
        _notifyMember(runConversation, groupParent);
        await _persistMember(runConversation, groupParent);
        if (outcome == 'completed' &&
            (groupParent == null || runMessageIds.isNotEmpty)) {
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
