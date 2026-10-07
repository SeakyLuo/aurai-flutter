part of 'chat_controller.dart';

extension TaskHandlerActions on ChatController {
  bool taskHandlerNeedsStop(String id) {
    final session = _executions.sessions[id];
    return session?.runningConversation != null ||
        session?.privateConversation != null;
  }

  Future<void> setTaskHandler(
    String id,
    String senderId, {
    required bool stopRunning,
  }) async {
    final task = await _targetConversation(id);
    if (!task.isTask) throw StateError('只有任务可以更换处理人');
    if (task.defaultSenderId == senderId) return;
    await _inConversation(task, () async {
      final queue = pendingMessageQueue;
      if (_submitting || queue.busy || changingConversation) {
        throw StateError('正在处理消息，请稍后再更换处理人');
      }
      final handler = await groupStore.loadAi(senderId);
      if (handler.sender.archived) throw StateError('请先恢复这位联系人');
      if (_submitting || queue.busy) {
        throw StateError('正在处理消息，请稍后再更换处理人');
      }
      final finished = _execution.runFinished;
      final privateFinished = _execution.privateRunFinished;
      if (finished != null || privateFinished != null) {
        if (!stopRunning) throw StateError('任务正在执行，请确认停止后再更换处理人');
        await _stopConversation();
        await finished;
        await privateFinished;
      }
      if (_submitting || queue.busy) {
        throw StateError('正在处理消息，请稍后再更换处理人');
      }
      if (taskHandlerNeedsStop(id)) {
        throw StateError('任务又开始了执行，请重新确认停止后更换处理人');
      }
      _submitting = true;
      queue.busy = true;
      _notifyRun(task);
      try {
        final previous = task.defaultSenderId;
        final now = DateTime.now().microsecondsSinceEpoch;
        await _store.writer.mutate(
          () => _store.database.transaction((txn) async {
            // The current task plan follows the task, not a previous assignment.
            await txn.delete(
              'private_task_state',
              where: 'conversation_id = ? AND sender_id = ?',
              whereArgs: [id, senderId],
            );
            await txn.update(
              'private_task_state',
              {'sender_id': senderId},
              where: 'conversation_id = ? AND sender_id = ?',
              whereArgs: [id, previous],
            );
            await txn.update(
              'conversations',
              {
                'default_sender_id': senderId,
                'run_state': 'idle',
                'error_detail': null,
              },
              where: 'id = ?',
              whereArgs: [id],
            );
            await txn.update(
              'conversation_members',
              {'left_at': now},
              where: 'conversation_id = ? AND sender_id = ?',
              whereArgs: [id, previous],
            );
            final updated = await txn.update(
              'conversation_members',
              {'left_at': null, 'joined_at': now, 'position': 1},
              where: 'conversation_id = ? AND sender_id = ?',
              whereArgs: [id, senderId],
            );
            if (updated == 0) {
              await txn.insert('conversation_members', {
                'conversation_id': id,
                'sender_id': senderId,
                'position': 1,
                'joined_at': now,
                'role': 'member',
              });
            }
          }),
        );
        for (final copy in {
          task,
          _viewConversation,
          ..._conversations,
          ..._executions.sessions.values
              .map((state) => state.conversation)
              .nonNulls,
        }.where((copy) => copy.id == id)) {
          copy.defaultSenderId = senderId;
          copy.runState = ChatRunState.idle;
          copy.errorDetail = null;
        }
        if (_viewConversation.id == id) _activeAi = handler;
        _updateConversationList(task);
        _conversationChanged();
      } finally {
        queue.busy = false;
        _submitting = false;
        _notifyRun(task);
      }
    });
  }
}
