part of 'chat_controller.dart';

extension GroupSleepRecovery on ChatController {
  Future<void> _recoverGroupSleep(String id, Set<String> members) async {
    final target = await _forwardTarget(id);
    await _inConversation(target, () => _recoverGroupSleepIn(id, members));
  }

  Future<void> _recoverGroupSleepIn(String id, Set<String> members) async {
    if (hasRunningTask) return;
    _systemEventLoading = true;
    try {
      final rows = await _store.database.query(
        'conversations',
        columns: ['id'],
        where: 'id = ? AND archived = 0',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) {
        await _groupSleeps.remove(id);
        return;
      }
      final conversation = id == activeConversation.id
          ? activeConversation
          : await _store.load(id);
      _runningConversation = conversation;
      _systemEventLoading = false;
      await _executeGroupChat(conversation, wakeMembers: members);
    } on Object catch (error, stack) {
      debugPrint('Group sleep recovery failed: $error\n$stack');
    } finally {
      _systemEventLoading = false;
      _runningConversation = null;
      _resumeForwardedReply();
      _conversationChanged();
      _drainGroupSystemNotices();
    }
  }
}
