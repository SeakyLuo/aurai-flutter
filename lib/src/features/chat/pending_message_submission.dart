part of 'chat_controller.dart';

extension PendingMessageSubmission on ChatController {
  PendingMessageQueue get pendingMessageQueue => _pendingMessageQueues
      .putIfAbsent(activeConversation.id, PendingMessageQueue.new);

  bool get shouldQueuePrivateMessage =>
      activeConversation.kind == ConversationKind.direct &&
      (isBusy || pendingMessageQueue.messages.isNotEmpty);

  Future<void> _loadPendingMessageQueues() async {
    final rows = await _store.database.query(
      'app_state',
      where:
          "key GLOB 'pending_message_queue:*' AND substr(key, 23) IN (SELECT id FROM conversations)",
    );
    for (final row in rows) {
      _pendingMessageQueues[(row['key'] as String).substring(
        22,
      )] = PendingMessageQueue.restore(
        row['value'] as String,
        _imageStore.directory,
      );
    }
  }

  Future<void> _enqueuePrivateMessage(
    String text, {
    required bool fromDraft,
  }) async {
    final conversation = activeConversation;
    final queue = pendingMessageQueue;
    if (queue.busy || _submitting) throw StateError('正在保存消息，请稍后再试');
    final message = AgentMessage(
      id: newMessageId(),
      role: AgentMessageRole.user,
      senderId: MessageSender.localUser.id,
      text: text,
      quote: fromDraft ? conversation.draftQuote : null,
      images: fromDraft ? List.of(draftImages) : const [],
      files: fromDraft ? List.of(draftFiles) : const [],
      createdAt: DateTime.now(),
    );
    final draft = conversation.draft;
    final mentions = List.of(conversation.draftMentions);
    queue.busy = true;
    _submitting = true;
    if (queue.messages.isEmpty) {
      queue.paused =
          conversation.runState == ChatRunState.stopping ||
          conversation.runState == ChatRunState.cancelled ||
          conversation.runState == ChatRunState.failed;
    }
    queue.messages.add(message);
    if (fromDraft) {
      conversation.draft = '';
      conversation.draftQuote = null;
      conversation.draftMentions.clear();
      draftImages.clear();
      draftFiles.clear();
    }
    _notifyRun(conversation);
    try {
      await _store.writer.save(
        conversation,
        makeActive: false,
        saveDraft: fromDraft,
        saveMessages: false,
        pendingMessageQueue: queue.encode(),
      );
    } on Object {
      queue.messages.remove(message);
      if (fromDraft) {
        conversation.draft = draft;
        conversation.draftQuote = message.quote;
        conversation.draftMentions.addAll(mentions);
        draftImages.addAll(message.images);
        draftFiles.addAll(message.files);
      }
      rethrow;
    } finally {
      queue.busy = false;
      _submitting = false;
      _notifyRun(conversation);
      _resumeForwardedReply();
    }
  }

  Future<void> removePendingMessage(String id) =>
      _inConversation(activeConversation, () async {
        final queue = pendingMessageQueue;
        if (queue.busy) return;
        final index = queue.messages.indexWhere((message) => message.id == id);
        final message = queue.messages.removeAt(index);
        queue.busy = true;
        _notifyRun(activeConversation);
        try {
          await _store.writer.save(
            activeConversation,
            makeActive: false,
            saveMessages: false,
            pendingMessageQueue: queue.encode(),
          );
        } on Object {
          queue.messages.insert(index, message);
          rethrow;
        } finally {
          queue.busy = false;
          _notifyRun(activeConversation);
          _resumeForwardedReply();
        }
      });

  bool _resumePendingMessages() {
    final conversation = _execution.conversation;
    if (conversation == null || conversation.kind != ConversationKind.direct)
      return false;
    final queue = pendingMessageQueue;
    if (queue.messages.isEmpty) return false;
    if (conversation.runState == ChatRunState.failed ||
        conversation.runState == ChatRunState.cancelled)
      queue.paused = true;
    if (queue.busy ||
        queue.paused ||
        hasRunningTask ||
        conversation.runState != ChatRunState.idle ||
        conversation.pendingGoal != null)
      return false;
    unawaited(
      _inConversation(conversation, () async {
        try {
          final needsSettings = await _dispatchPendingMessages(
            stopRunning: false,
          );
          if (needsSettings) {
            queue.paused = true;
            queue.error = StateError('请配置模型后发送待发送消息');
            _notifyRun(conversation);
          }
        } on Object catch (error) {
          queue.paused = true;
          queue.error = error;
          _notifyRun(conversation);
        }
      }),
    );
    return true;
  }

  Future<bool> sendPendingMessages({String? messageId}) => _inConversation(
    activeConversation,
    () => _dispatchPendingMessages(stopRunning: true, messageId: messageId),
  );

  Future<bool> _dispatchPendingMessages({
    required bool stopRunning,
    String? messageId,
  }) async {
    final conversation = activeConversation;
    final queue = pendingMessageQueue;
    if (queue.busy || queue.messages.isEmpty) return false;
    final batch = queue.messages
        .where((message) => messageId == null || message.id == messageId)
        .toList();
    if (batch.isEmpty) return false;
    final remainingPaused = queue.paused;
    queue.busy = true;
    queue.paused = true;
    _notifyRun(conversation);
    var committed = false;
    String? previousPending;
    ChatRunState? previousState;
    String? previousError;
    final sent = <AgentMessage>[];
    try {
      if (!(await _directReplyContext(conversation)).config.isConfigured)
        return true;
      if (stopRunning && isBusy) {
        final finished = identical(_privateConversation, conversation)
            ? _execution.privateRunFinished?.future
            : _execution.runFinished?.future;
        await _stopConversation();
        await finished;
      }
      // No history mutation happens until the current execution has exited.
      previousPending = conversation.pendingGoal;
      previousState = conversation.runState;
      previousError = conversation.errorDetail;
      cancelSearchNavigation();
      final now = DateTime.now();
      for (var i = 0; i < batch.length; i++) {
        final message = batch[i];
        sent.add(
          AgentMessage(
            id: message.id,
            role: AgentMessageRole.user,
            senderId: MessageSender.localUser.id,
            text: message.text,
            quote: message.quote,
            images: message.images,
            files: message.files,
            createdAt: now.add(Duration(microseconds: i)),
          ),
        );
      }
      conversation.runState = ChatRunState.idle;
      conversation.errorDetail = null;
      conversation.messages.addAll(sent);
      conversation.messageCount += sent.length;
      conversation.pendingGoal = sent.map((message) => message.text).join('\n');
      final sentIds = sent.map((message) => message.id).toSet();
      final remaining = queue.messages
          .where((message) => !sentIds.contains(message.id))
          .toList();
      await _store.writer.save(
        conversation,
        makeActive: false,
        saveRuntime: true,
        pendingMessageQueue: jsonEncode({
          'paused': remainingPaused,
          'messages': remaining.map((message) => message.toJson()).toList(),
        }),
      );
      committed = true;
      conversation.steps.clear();
      queue.messages.removeWhere((message) => sentIds.contains(message.id));
      queue.paused = remainingPaused;
      queue.error = null;
      queue.busy = false;
      _updateConversationList(conversation);
      _notifyRun(conversation);
      await continuePending();
      return false;
    } on Object {
      if (!committed && sent.isNotEmpty) {
        final ids = sent.map((message) => message.id).toSet();
        conversation.messages.removeWhere(
          (message) => ids.contains(message.id),
        );
        conversation.messageCount -= sent.length;
        conversation.pendingGoal = previousPending;
        conversation.runState = previousState!;
        conversation.errorDetail = previousError;
      }
      rethrow;
    } finally {
      if (!committed) queue.busy = false;
      _notifyRun(conversation);
    }
  }
}
