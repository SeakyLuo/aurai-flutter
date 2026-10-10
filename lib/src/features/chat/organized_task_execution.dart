part of 'chat_controller.dart';

extension OrganizedTaskExecution on ChatController {
  Future<DeferredToolExecution> _prepareTask(
    ToolCall call,
    bool Function() cancelled, {
    required Conversation source,
    required ExecutionReplyContext reply,
    required String sourceMessageId,
  }) async {
    final taskId = call.arguments['taskId'] as String?;
    final instruction = call.arguments['task'] as String?;
    final startExecution = call.arguments['startExecution'] as bool? ?? true;
    late final Conversation task;
    if (taskId == null) {
      task = Conversation.empty()
        ..defaultSenderId = reply.senderId
        ..storedTitle = call.arguments['title'] as String;
      await _store.writer.mutate(
        () => _store.database.transaction((txn) async {
          await txn.insert('conversations', conversationRow(task));
          await txn.insert('organized_tasks', {
            'task_id': task.id,
            'conversation_id': source.id,
            'source_message_id': sourceMessageId,
          });
        }),
      );
      task.isStored = true;
    } else {
      final rows = await _store.database.query(
        'conversations',
        columns: ['id'],
        where:
            "id = ? AND kind = 'direct' AND personal_chat = 0 AND mode = 'normal' AND default_sender_id = ? AND $localUserConversation",
        whereArgs: [taskId, reply.senderId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('找不到当前 AI 的这项任务');
      task = await _forwardTarget(taskId);
      if (task.isArchived) {
        await _store.writer.updateMetadata(task, {'archived': 0});
        task.isArchived = false;
      }
    }
    final notice = AgentMessage(
      id: newMessageId(),
      role: AgentMessageRole.user,
      senderId: reply.senderId,
      sender: reply.sender,
      text: call.arguments['description'] as String? ?? task.title,
      isSystem: true,
      interactive: InteractiveMessage.card(
        revision: 0,
        title: '',
        body: '',
        buttons: const [],
        participation: {
          'presentation': 'message',
          '_taskSource': {
            'conversationId': source.id,
            'messageId': sourceMessageId,
          },
          if (startExecution) '_taskExecution': instruction!,
        },
      ),
      createdAt: DateTime.now(),
    );
    if (!startExecution) {
      await _store.writer.mutate(
        () => _store.database.transaction((txn) async {
          await txn.insert('messages', messageRow(task.id, notice));
          await txn.rawUpdate(
            'UPDATE conversations SET message_count = message_count + 1, preview = ?, updated_at = ? WHERE id = ?',
            [notice.text, notice.createdAt.microsecondsSinceEpoch, task.id],
          );
        }),
      );
      _publishInteractiveChange(task.id, notice, source: task);
    }
    final taskMessage = await _sendTaskCardMessage(
      source,
      task,
      reply,
      call,
      startExecution: startExecution,
    );
    final initial = <String, Object?>{
      'taskId': task.id,
      'taskMessageId': taskMessage.id,
      'conversationId': task.id,
      'title': task.title,
    };
    return DeferredToolExecution(
      initialOutput: initial,
      cancel: () => _inConversation(task, _stopConversation),
      finish: () => _inConversation(task, () async {
        if (cancelled()) throw const AgentCancelled();
        final messageId = await _enqueuePendingMessage(
          notice,
          fromDraft: false,
          dispatch: false,
        );
        await _store.database.insert('memory_message_origins', {
          'message_id': messageId,
          'author_id': reply.senderId,
          'source_message_id': sourceMessageId,
        });
        if (cancelled()) {
          await removePendingMessage(messageId);
          throw const AgentCancelled();
        }
        final needsConfiguration = await _dispatchPendingMessages(
          messageId: messageId,
        );
        if (needsConfiguration) throw StateError('请先为这位联系人配置模型，再继续任务');
        await _waitForTaskWork();
        final status = switch (task.runState) {
          ChatRunState.cancelled ||
          ChatRunState.stopping => ToolResultStatus.cancelled,
          ChatRunState.failed ||
          ChatRunState.interrupted => ToolResultStatus.error,
          _ => ToolResultStatus.success,
        };
        return ToolResult(
          callId: call.id,
          toolName: call.name,
          status: status,
          output: {
            ...initial,
            'pending': false,
            if (status == ToolResultStatus.error) 'error': task.errorDetail,
            if (status == ToolResultStatus.cancelled) 'cancelled': true,
            'sources': [
              for (final source in webSourcesFromSteps(task.steps).values)
                {
                  'title': source.title,
                  'url': source.url,
                  'siteName': source.siteName,
                  'publishedAt': source.publishedAt,
                },
            ],
            'answer':
                task.messages
                    .where(
                      (message) =>
                          message.role == AgentMessageRole.assistant &&
                          !message.isReasoning,
                    )
                    .lastOrNull
                    ?.text ??
                '',
          },
        );
      }),
    );
  }

  Future<void> _waitForTaskWork() async {
    final session = _execution;
    final queue = pendingMessageQueue;
    final finished = Completer<void>();
    void check() {
      if (session.runningConversation == null &&
          !session.submitting &&
          !queue.busy &&
          (queue.messages.isEmpty || queue.paused) &&
          !finished.isCompleted) {
        finished.complete();
      }
    }

    addListener(check);
    try {
      check();
      await finished.future;
    } finally {
      removeListener(check);
    }
  }
}
