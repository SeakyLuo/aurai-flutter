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
    final summaryOwner = groupParent ?? runConversation;
    final historyVersion = _store.writer.historyVersion(summaryOwner.id);
    final alongsideGroup = identical(runConversation, _privateConversation);
    final messages = runConversation.messages;
    final steps = runConversation.steps;
    final runConfig = reply.config;
    final diagnosticCalls = <String, Object?>{};
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
    final htmlEvents = await _pendingHtmlEvents(
      runConversation,
      reply.senderId,
    );
    final callbackEvents = await MessageCallbacks(
      _store.database,
    ).pending(runConversation.id, reply.senderId);
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
    String? failureDiagnostic;
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
        throw AgentCancelled();
      final provider = switch (runConfig.service) {
        ModelService.openAi => OpenAiResponsesProvider(
          runConfig,
          systemPrompt: systemPrompt,
          summaryConfig: modelSettings.activeConfig,
          sharedContext: groupParent?.sharedContext,
        ),
        ModelService.openRouter ||
        ModelService.deepSeek ||
        ModelService.qwen ||
        ModelService.kimi ||
        ModelService.glm => DeepSeekResponsesProvider(
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
      );
      if (groupParent != null) {
        tools.removeWhere((t) => t.definition.name == 'sendGroupMessage');
        Future<DateTime?> scheduleGroupSleep(Duration duration) async {
          final dispatcher = _groupDispatcher!;
          final until = duration.isNegative
              ? null
              : DateTime.now().add(duration);
          if (until == null) {
            await _groupSleeps.remove(groupParent.id, reply.senderId);
          } else {
            await _groupSleeps.save(groupParent.id, reply.senderId, until);
          }
          if (dispatcher.stopped ||
              dispatcher.closed ||
              dispatcher.paused.contains(reply.senderId) ||
              _removedGroupMembers.contains(reply.senderId)) {
            await _groupSleeps.remove(groupParent.id, reply.senderId);
            throw AgentCancelled();
          }
          return dispatcher.sleepUntil(reply.senderId, until);
        }

        tools.add(GroupSleepTool(scheduleGroupSleep));
        tools.add(
          GroupMessageTool(
            (arguments) => _deliverGroupMessage(
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
      final registry = ToolRegistry(tools: tools, capabilities: capabilities);
      registry.load(
        await recentConversationTools(_store.database, runConversation.id),
      );
      registry.load([
        'sendGroupMessage',
        if (groupParent != null) 'sleepGroupChat',
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
      if (scheduled) {
        await _platform.startAgentSession(
          '正在执行定时任务',
          conversationId: runConversation.id,
        );
        sessionStarted = true;
      }
      if (runConversation.runState == ChatRunState.stopping)
        throw AgentCancelled();
      var turnOrdinal = 0;
      late String modelTurnId;

      final stepActivityIndices = <int>[];
      String? turnMessageId;
      int? turnActivityIndex;
      String? reasoningMessageId;
      int? reasoningActivityIndex;
      int? outputMessageIndex;
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
        ],
        contextSummary: groupHistory == null
            ? runConversation.contextSummary
            : groupParent!.contextSummary,
        personalContext: () async => [
          responsePreferences.instructions,
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
          if (!sessionStarted) {
            await _platform.startAgentSession(
              toolTitle(call.name),
              conversationId: runConversation.id,
            );
            sessionStarted = true;
          }
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
          if (groupParent != null || text.trim().isEmpty) return;
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
          if (groupParent != null || text.trim().isEmpty) return;
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
            elapsedMilliseconds: executionWatch.elapsedMilliseconds,
            isTask: runConversation.hasExecutionProcess,
            intermediateMessageIds: List.unmodifiable(
              groupParent == null
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
                  : answer.interactive != null || answer.htmlGame != null
                  ? activities
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
      runConversation.liveToolSteps.clear();
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
        final keepActivity =
            (groupParent == null && runConversation.hasExecutionProcess) ||
            messages.last.runId == runId ||
            activities.any(
              (activity) => activity.toolName != null || activity.isReasoning,
            );
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
            isReasoning: last.isReasoning,
            quote: last.quote,
            senderId: last.senderId,
            sender: last.sender,
            text: last.text,
            images: last.images,
            interactive: last.interactive,
            htmlGame: last.htmlGame,
            files: last.files,
            runId: last.runId,
            modelTurnId: last.modelTurnId,
            createdAt: last.createdAt,
            taskSummary:
                !runConversation.hasExecutionProcess &&
                    !activities.any((activity) => activity.isReasoning)
                ? null
                : AgentTaskSummary(
                    elapsedMilliseconds: executionWatch.elapsedMilliseconds,
                    isTask: runConversation.hasExecutionProcess,
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
                          isReasoning: activity.isReasoning,
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
        runConversation.errorDetail = errorMessage(error);
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
            reply: outcome == 'completed' && runMessageIds.isNotEmpty
                ? messages.lastWhere((m) => runMessageIds.contains(m.id)).text
                : '',
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

  Future<void> _persistRun(Conversation conversation) =>
      _store.writer.save(conversation, makeActive: false, saveRuntime: true);

  void _notifyRun(Conversation conversation) {
    if (conversation.kind == ConversationKind.group &&
        _viewConversation.id == conversation.id &&
        !identical(_viewConversation, conversation)) {
      final messages =
          {
            for (final message in _viewConversation.messages)
              message.id: message,
            for (final message in conversation.messages) message.id: message,
          }.values.toList()..sort((a, b) {
            final order = a.createdAt.compareTo(b.createdAt);
            return order == 0 ? a.id.compareTo(b.id) : order;
          });
      _viewConversation.messages
        ..clear()
        ..addAll(messages);
    }
    _updateConversationList(conversation);
    _conversationChanged();
  }
}
