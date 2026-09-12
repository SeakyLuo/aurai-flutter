part of 'chat_controller.dart';

extension ConversationActions on ChatController {
  Future<void> markActiveConversationRead() async {
    final conversation = activeConversation;
    if (conversation.runState != ChatRunState.idle ||
        conversation.pendingGoal != null ||
        conversation.activeRunId == null ||
        conversation.seenRunId == conversation.activeRunId)
      return;
    final previous = conversation.seenRunId;
    conversation.seenRunId = conversation.activeRunId;
    try {
      await _persist();
    } on Object {
      conversation.seenRunId = previous;
      rethrow;
    }
    _updateConversationList();
    _conversationChanged();
  }

  Conversation _targetConversation(String? id) =>
      id == null || id == activeConversation.id
      ? activeConversation
      : _conversations.firstWhere((item) => item.id == id);

  Future<void> toggleConversationPin([String? id]) async {
    final conversation = _targetConversation(id);
    final previous = conversation.isPinned;
    conversation.isPinned = !previous;
    try {
      await _saveConversationHeader(conversation, {
        'pinned': conversation.isPinned ? 1 : 0,
      });
    } on Object {
      conversation.isPinned = previous;
      rethrow;
    } finally {
      _conversationChanged();
    }
  }

  Future<void> renameConversation(String id, String title) async {
    final name = title.trim();
    if (name.isEmpty) throw ArgumentError('请输入会话名称');
    final conversation = _targetConversation(id);
    final previous = conversation.storedTitle;
    conversation.storedTitle = name;
    try {
      await _saveConversationHeader(conversation, {'title': name});
    } on Object {
      conversation.storedTitle = previous;
      rethrow;
    } finally {
      _conversationChanged();
    }
  }

  Future<void> _saveConversationHeader(
    Conversation conversation,
    Map<String, Object?> values,
  ) async {
    if (conversation.id == activeConversation.id) {
      await _persist();
      _updateConversationList();
    } else {
      await _store.writer.flush();
      await _store.database.update(
        'conversations',
        values,
        where: 'id = ?',
        whereArgs: [conversation.id],
      );
    }
  }

  Future<void> deleteConversation([String? id]) async {
    final removed = _targetConversation(id);
    final isActive = removed.id == activeConversation.id;
    if (removed.id == runningConversationId ||
        changingConversation ||
        (isActive && (isBusy || addingImages))) {
      throw StateError('请等待当前操作完成，再删除会话');
    }
    final images = await _store.attachmentPaths(removed.id);
    if (isActive) {
      final candidates = await _store.reader.list();
      final remaining = candidates.where((item) => item.id != removed.id);
      final replacement = remaining.isEmpty
          ? _newConversation
          : remaining.first.id == runningConversationId
          ? _runningConversation!
          : await _store.load(remaining.first.id);
      await _store.delete(removed, replacement);
      _activeConversation = replacement;
      _store.writer.retain([
        ...replacement.messages,
        if (_runningConversation != null && _runningConversation != replacement)
          ..._runningConversation!.messages,
      ]);
    } else {
      await _store.writer.flush();
      await _store.database.transaction((txn) async {
        await txn.delete(
          'conversations',
          where: 'id = ?',
          whereArgs: [removed.id],
        );
        await txn.delete(
          'app_state',
          where: 'key IN (?, ?)',
          whereArgs: [
            'context_summary:${removed.id}',
            'seen_run:${removed.id}',
          ],
        );
      });
    }
    _conversations.removeWhere((conversation) => conversation.id == removed.id);
    _updateConversationList();
    _conversationChanged();
    for (final path in images) {
      await File(path).delete();
    }
  }
}
