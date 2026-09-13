part of 'chat_controller.dart';

extension ScheduledExecution on ChatController {
  Future<void> _runScheduled() async {
    if (_claimingSchedule) return;
    final wasBusy = hasRunningTask;
    _claimingSchedule = true;
    Map<String, Object?>? task;
    Conversation? conversation;
    var outcome = 'failed';
    var enteredRuntime = false;
    String? failure;
    try {
      task = await scheduledTasks.take(wasBusy);
      if (task == null) return;
      if (needsConfiguration) throw StateError('请先配置模型');
      conversation = Conversation.empty()
        ..isScheduledTask = true
        ..storedTitle = task['title'] as String;
      _runningConversation = conversation;
      final instruction =
          '现在执行已安排的任务，不要重复创建计划。原计划：${task['scheduleLabel']}。任务内容：\n${task['prompt']}';
      conversation.messages.add(
        AgentMessage(
          id: newMessageId(),
          role: AgentMessageRole.user,
          senderId: MessageSender.localUser.id,
          text: instruction,
          createdAt: DateTime.now(),
        ),
      );
      conversation.messageCount = 1;
      await _store.writer.save(conversation, makeActive: false);
      _updateConversationList(conversation);
      _conversationChanged();
      enteredRuntime = true;
      await _executeConversation(conversation, scheduled: true);
      outcome = 'completed';
    } on Object catch (error) {
      failure = error is StateError
          ? error.message
          : conversation?.errorDetail ?? '执行未完成，请检查模型和设备权限';
      if (conversation?.runState == ChatRunState.cancelled)
        outcome = 'cancelled';
    } finally {
      try {
        if (task != null) {
          // End the prestarted service even if execution failed before runtime startup.
          try {
            await _platform.endAgentSession(
              enteredRuntime ? 'cancelled' : 'failed',
              conversationId: conversation?.id ?? '',
              title: conversation?.title ?? '',
              reply: '',
            );
          } finally {
            await scheduledTasks.finish(
              task['id'] as String,
              outcome,
              conversation?.id,
              failure,
            );
          }
        }
      } finally {
        if (task != null) {
          _runningConversation = null;
          if (conversation != null) _updateConversationList(conversation);
        }
        _claimingSchedule = false;
        _conversationChanged();
      }
    }
  }
}
