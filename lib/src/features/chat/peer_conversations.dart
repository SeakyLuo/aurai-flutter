part of 'chat_controller.dart';

/// Private AI conversations have their own mailboxes and provider runs. They do
/// not borrow the foreground human chat or the singleton group dispatcher.
class _PeerSession {
  _PeerSession(this.conversation);
  final Conversation conversation;
  late GroupDispatcher dispatcher;
  final runtimes = <String, AgentRuntime>{};
  final runIds = <String, String>{};
}

extension PeerConversations on ChatController {
  Future<_PeerSession> _loadPeerSession(String id) async {
    final conversation = await _store.load(id);
    final members = await groupStore.members(id);
    conversation.beginSharedContext();
    final history = await _store.reader.messages(
      id,
      forModel: true,
      afterCheckpoint: conversation.contextSummary?.throughMessageId,
    );
    final session = _PeerSession(conversation);
    session.dispatcher = GroupDispatcher(
      history: history,
      members: members.map((m) => m.sender.id),
      paused: {},
      respond: (senderId, history) => _replyToPeer(session, senderId, history),
      failed: (senderId, error) async {
        // Failure diagnostics remain in the local log, not a fake chat message.
        await ExecutionLog.write({
          'event': 'peer_dispatch_error',
          'conversationId': id,
          'senderId': senderId,
          'diagnostic': error.toString(),
        }, apiKey: '');
      },
    );
    final pending = _peerSessions[id];
    unawaited(
      session.dispatcher.done.then((_) {
        if (identical(_peerSessions[id], pending)) _peerSessions.remove(id);
      }),
    );
    return session;
  }

  Future<Map<String, Object?>> _sendPeerMessage(
    String id,
    String senderId,
    String text, {
    List<MessageImage> images = const [],
    MessageQuote? quote,
  }) async {
    text = text.trim();
    if ((text.isEmpty && images.isEmpty) || text.length > 20000)
      throw ArgumentError('消息需为 1–20000 字');
    var pending = _peerSessions.putIfAbsent(id, () => _loadPeerSession(id));
    _PeerSession session;
    try {
      session = await pending;
    } on Object {
      if (identical(_peerSessions[id], pending)) _peerSessions.remove(id);
      rethrow;
    }
    if (session.dispatcher.closed) {
      if (identical(_peerSessions[id], pending)) _peerSessions.remove(id);
      pending = _peerSessions.putIfAbsent(id, () => _loadPeerSession(id));
      session = await pending;
    }
    if (session.dispatcher.stopped) throw const AgentCancelled();
    session.dispatcher.hold();
    try {
      final profile = await groupStore.loadAi(senderId);
      final message = AgentMessage(
        id: newMessageId(),
        role: AgentMessageRole.assistant,
        senderId: senderId,
        sender: profile.sender,
        text: text,
        images: images,
        quote: quote,
        createdAt: DateTime.now(),
        runId: session.runIds[senderId],
      );
      await _store.writer.mutate(
        () => _store.database.transaction((txn) async {
          await txn.insert('messages', messageRow(id, message));
          final attachments = txn.batch();
          for (var i = 0; i < images.length; i++) {
            attachments.insert(
              'attachments',
              attachmentRow(id, images[i], i, messageId: message.id),
            );
          }
          await attachments.commit(noResult: true);
          await txn.rawUpdate(
            'UPDATE conversations SET message_count = message_count + 1, preview = ?, updated_at = ? WHERE id = ?',
            [text, message.createdAt.microsecondsSinceEpoch, id],
          );
        }),
      );
      session.conversation.messages.add(message);
      session.conversation.messageCount++;
      _store.writer.remember([message]);
      session.dispatcher.acknowledge(senderId);
      session.dispatcher.receive([message]);
      return {'sent': true, 'messageId': message.id, 'conversationId': id};
    } finally {
      session.dispatcher.release();
    }
  }

  Future<void> _replyToPeer(
    _PeerSession session,
    String senderId,
    List<AgentMessage> snapshot,
  ) async {
    final conversation = session.conversation;
    final historyVersion = _store.writer.historyVersion(conversation.id);
    final profile = await groupStore.loadAi(senderId);
    final reply = _profileReplyContext(profile, group: false);
    final config = reply.config;
    if (!config.isConfigured) throw StateError('${profile.sender.name} 尚未配置模型');
    final prompt =
        '${reply.systemPrompt}\n'
        '当前是你与另一位 AI 好友的私聊，会话 ${conversation.id}。对方不是人类用户，不要把对方的发言称为用户指令。'
        '像正常朋友聊天，结合性格决定是否回复，不必每条都接，不要为续聊反复提问或客套。'
        '普通输出是私下思考，不会发送给好友。发言必须调用 sendConversationMessage，conversationId 使用当前会话；可以连续发多条。'
        '没有要说的就输出 [[NO_REPLY]]，等待对方新消息；不要循环查消息。私聊创建本身不强迫发言。';
    final memory = await aiMemory(profile, scope: conversation.id);
    final skills = await aiSkills(senderId);
    final documents = AiDocumentScope(_store.database, senderId);
    await documents.initialize();
    final provider = switch (config.service) {
      ModelService.openAi => OpenAiResponsesProvider(
        config,
        systemPrompt: prompt,
        summaryConfig: modelSettings.activeConfig,
        sharedContext: conversation.sharedContext,
      ),
      _ => DeepSeekResponsesProvider(
        config,
        systemPrompt: prompt,
        summaryConfig: modelSettings.activeConfig,
        sharedContext: conversation.sharedContext,
      ),
    };
    final runId = await _store.runs.start(
      conversation.id,
      snapshot.last.id,
      config,
      senderId: senderId,
      group: true,
      systemPrompt: prompt,
      customInstructions: profile.preferences.customInstructions,
      responsePreferences: profile.preferences.responses,
    );
    session.runIds[senderId] = runId;
    final watch = Stopwatch()..start();
    final registry = ToolRegistry(
      tools: _createTools(
        conversation: conversation,
        senderId: senderId,
        messageId: snapshot.last.id,
        providerLabel: config.displayName,
        memory: memory,
        skills: skills,
        documents: documents,
        history: snapshot,
        webSources: WebSourceRegistry(),
        questionTool: AskUserTool(conversation.id, (question) {
          pendingQuestion = question;
          _conversationChanged();
        }),
      ),
      capabilities: capabilities,
    );
    registry.load([
      'sendConversationMessage',
      'listFriends',
      'createConversation',
    ]);
    final runtime = AgentRuntime(
      provider: provider,
      registry: registry,
      executor: GroupToolExecutor(
        registry: registry,
        queue: _groupToolQueue,
        cancelled: () => session.dispatcher.stopped,
        waitForInteraction: () async {
          await pendingQuestion?.result.future;
        },
        confirm: (call, definition) => _confirm(
          call,
          definition,
          runId: runId,
          conversationId: conversation.id,
          senderId: senderId,
          screenAccess: profile.preferences.screenAccess,
        ),
      ),
    );
    session.runtimes[senderId] = runtime;
    var ordinal = 0;
    late String turnId;
    final shapes = <String, Object?>{};
    try {
      await runtime.run(
        conversation: [
          for (final message in snapshot.where((m) => !m.isFailure))
            AgentMessage(
              id: message.id,
              role: AgentMessageRole.user,
              senderId: message.senderId,
              sender: message.sender,
              text:
                  '【私聊记录，${message.sender!.name}（${message.senderId}）；消息 ${message.id}】\n${message.text}',
              createdAt: message.createdAt,
              images: message.images,
              files: message.files,
            ),
        ],
        contextSummary: conversation.contextSummary,
        onContextSummary: (summary) async {
          await _store.writer.saveContextSummary(
            conversation.id,
            summary,
            historyVersion: historyVersion,
          );
          if (_store.writer.historyVersion(conversation.id) == historyVersion) {
            conversation.contextSummary = summary;
          }
        },
        personalContext: () async => [
          profile.preferences.responses.instructions,
          profile.preferences.customInstructions,
          await memory.sharedContext(),
        ].join('\n\n'),
        onStepsChanged: (_) {},
        onTurnStarted: () async {
          turnId = await _store.runs.startTurn(
            conversation.id,
            runId,
            ordinal++,
          );
        },
        onTurnCompleted: (turn) => _store.runs.finishTurn(turnId, turn),
        onToolStarted: (call) async {
          shapes[call.id] = ExecutionLog.argumentShape(call.arguments);
          await _store.runs.startTool(conversation.id, runId, turnId, call);
        },
        onToolCompleted: (result) async {
          await _store.runs.finishTool(runId, result);
          final shape = shapes.remove(result.callId);
          if (result.status == ToolResultStatus.error)
            await ExecutionLog.write({
              'event': 'tool_error',
              'conversationId': conversation.id,
              'senderId': senderId,
              'senderName': profile.sender.name,
              'runId': runId,
              'model': config.model,
              'tool': result.toolName,
              'callId': result.callId,
              'argumentShape': shape,
              'result': result.output,
            }, apiKey: config.apiKey);
        },
      );
      await _store.runs.finish(runId, 'completed', watch.elapsedMilliseconds);
    } on Object catch (error, stack) {
      final diagnostic = '$error\n$stack'.replaceAll(
        config.apiKey,
        '[redacted]',
      );
      await ExecutionLog.write({
        'event': 'run_error',
        'conversationId': conversation.id,
        'senderId': senderId,
        'senderName': profile.sender.name,
        'runId': runId,
        'model': config.model,
        'diagnostic': diagnostic,
      }, apiKey: config.apiKey);
      await _store.runs.finish(
        runId,
        error is AgentCancelled ? 'cancelled' : 'failed',
        watch.elapsedMilliseconds,
        error: errorMessage(error),
        diagnostic: diagnostic,
      );
    } finally {
      session.runIds.remove(senderId);
      session.runtimes.remove(senderId);
    }
  }

  void _stopPeerSessions() {
    for (final pending in _peerSessions.values) {
      unawaited(
        pending.then((session) async {
          session.dispatcher.stop();
          for (final runtime in session.runtimes.values.toList()) {
            await runtime.cancel();
          }
        }),
      );
    }
  }
}
