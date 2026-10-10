part of 'chat_controller.dart';

extension PrivateChatRest on ChatController {
  Future<void> _consumeSleepDraft(String key, String draft) async {
    await _store.database.delete(
      'app_state',
      where: 'key = ? AND value = ?',
      whereArgs: [key, draft],
    );
  }

  bool _endsRestRun(ToolResult result, VoidCallback onSleep) {
    if (result.status != ToolResultStatus.success) return false;
    if (result.toolName == 'sleepChat') onSleep();
    return const [
      'sleepGroupChat',
      'sleepChat',
      'pauseAutoReply',
    ].contains(result.toolName);
  }

  AgentMessage _sleepWakeMessage(String runId, String reason) => AgentMessage(
    id: 'sleep-wake:$runId',
    role: AgentMessageRole.user,
    senderId: MessageSender.localUser.id,
    isSystem: true,
    text:
        '你安排的睡眠已到期。休息原因：$reason\n这是定时唤醒事件，不是用户重复发送原指令。读取最新上下文，保留已经完成的操作，不要重复发送旧消息。按需要继续工作、回复或再次睡眠。',
    createdAt: DateTime.now(),
  );

  List<AgentTool> _privateRestTools(
    Conversation conversation,
    String senderId,
  ) => [
    for (final name in ChatRestTool.names)
      ChatRestTool(name, (operation, arguments) async {
        if (conversation.runState == ChatRunState.stopping) {
          throw const AgentCancelled();
        }
        if (operation == 'sleepChat') {
          final seconds = arguments['seconds'] as int;
          final until = seconds == -1
              ? null
              : DateTime.now().add(Duration(seconds: seconds));
          final batch = _store.database.batch();
          for (final field in ['draft', 'reason']) {
            batch.insert('app_state', {
              'key': 'group_sleep_$field:${conversation.id}:$senderId',
              'value': arguments[field] as String,
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await batch.commit(noResult: true);
          await GroupParticipation(
            _store.database,
          ).setMembers(conversation.id, {senderId}, false);
          if (until == null) {
            await _groupSleeps.remove(conversation.id, senderId);
          } else {
            await _groupSleeps.save(conversation.id, senderId, until);
          }
          if (conversation.runState == ChatRunState.stopping) {
            await _groupSleeps.remove(conversation.id, senderId);
            throw const AgentCancelled();
          }
          _conversationChanged();
          return {
            'sleeping': until != null,
            'waitingForNewMessage': seconds == -1,
            'wakeAt': until == null ? null : localIsoTime(until),
            'reason': arguments['reason'],
          };
        }
        final paused = operation == 'pauseAutoReply';
        await GroupParticipation(_store.database).setMembers(
          conversation.id,
          {senderId},
          paused,
          reason: arguments['reason'] as String?,
        );
        if (paused) {
          await _groupSleeps.reload();
          await PrivateTaskState(
            _store.database,
            conversation.id,
            senderId,
          ).pause(arguments['reason'] as String);
        }
        MessageCallbacks.changes.add(null);
        _conversationChanged();
        return {'paused': paused};
      }),
  ];

  Future<void> _recoverConversationSleep(String id, Set<String> members) async {
    if (_callbackConversations.contains(id)) return;
    final rows = await _store.database.query(
      'conversations',
      columns: ['kind', 'archived'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty || rows.single['archived'] == 1) {
      await _groupSleeps.remove(id);
      return;
    }
    if (rows.single['kind'] == 'group') {
      await _recoverGroupSleep(id, members);
      return;
    }
    final state = _executions.sessions[id];
    if (state?.runningConversation != null ||
        state?.submitting == true ||
        state?.systemEventLoading == true)
      return;
    final conversation = await _forwardTarget(id);
    await _inConversation(conversation, () async {
      if (hasRunningTask) return;
      final reply = await _directReplyContext(conversation);
      final until = _groupSleeps.forGroup(id)[reply.senderId];
      if (until == null || until.isAfter(DateTime.now())) return;
      final reason = await _groupSleepDraft(
        'group_sleep_reason:$id:${reply.senderId}',
      );
      await _groupSleeps.remove(id, reply.senderId);
      _runningConversation = conversation;
      try {
        await _executeMember(
          conversation,
          reply: reply,
          sleepWakeReason: reason,
        );
      } finally {
        _runningConversation = null;
        _resumeForwardedReply();
        _notifyRun(conversation);
      }
    });
  }

  Future<void> _resumePrivateReply(
    Conversation conversation,
    String senderId,
  ) async {
    if (_groupSleeps.forGroup(conversation.id).containsKey(senderId)) {
      await _groupSleeps.remove(conversation.id, senderId);
    }
    final paused = await GroupParticipation(
      _store.database,
    ).paused(conversation.id);
    if (paused.contains(senderId)) {
      await GroupParticipation(
        _store.database,
      ).setMembers(conversation.id, {senderId}, false);
      MessageCallbacks.changes.add(null);
    }
  }
}
