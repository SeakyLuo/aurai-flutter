part of 'chat_controller.dart';

extension ConversationSearchNavigation on ChatController {
  Future<String?> firstUnreadMessageId() async {
    final conversation = activeConversation;
    if (conversation.kind == ConversationKind.group) {
      await _store.writer.flush();
      await GroupUnreadMessages(_store.database).load([conversation]);
      if (conversation.unreadMessageCount == 0) return null;
      final rows = await _store.database.rawQuery(
        "SELECT COALESCE((SELECT parent_message_id FROM message_quick_replies WHERE message_id = messages.id), id) AS target FROM messages WHERE conversation_id = ? AND sender_id != ? AND role = 'assistant' AND kind NOT IN ('commentary', 'system') AND (created_at > ? OR (created_at = ? AND id > ?)) AND (interactive_json IS NULL OR json_extract(interactive_json, '\$.participation.audience') IS NULL OR EXISTS (SELECT 1 FROM json_each(interactive_json, '\$.participation.audience') WHERE value = ?)) ORDER BY created_at, id LIMIT 1",
        [
          conversation.id,
          MessageSender.localUser.id,
          conversation.groupReadAt,
          conversation.groupReadAt,
          conversation.groupReadId,
          MessageSender.localUser.id,
        ],
      );
      return rows.isEmpty ? null : rows.single['target'] as String;
    }
    if (conversation.runState != ChatRunState.idle ||
        conversation.pendingGoal != null ||
        conversation.activeRunId == null ||
        conversation.activeRunId == conversation.seenRunId)
      return null;
    final rows = await _store.database.query(
      'messages',
      columns: ['id'],
      where:
          "conversation_id = ? AND run_id = ? AND role = 'assistant' AND kind NOT IN ('system', 'quick_reply', 'commentary', 'reasoning')",
      whereArgs: [conversation.id, conversation.activeRunId],
      orderBy: 'created_at, id',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['id'] as String;
  }

  List<AgentMessage> get visibleMessages {
    final conversation = activeConversation;
    final window = conversation.searchMessages;
    if (window == null)
      return messages
          .where((message) => message.quickReplyToId == null)
          .toList();
    if (conversation.searchHasLater) return window;
    final combined = {
      for (final message in window) message.id: message,
      for (final message in messages)
        if (!message.createdAt.isBefore(window.first.createdAt))
          message.id: message,
    }.values.toList();
    combined.sort((a, b) {
      final order = a.createdAt.compareTo(b.createdAt);
      return order == 0 ? a.id.compareTo(b.id) : order;
    });
    return combined.where((message) => message.quickReplyToId == null).toList();
  }

  bool get hasSearchWindow => activeConversation.searchMessages != null;
  bool get visibleHasEarlier => hasSearchWindow
      ? activeConversation.searchHasEarlier
      : activeConversation.hasEarlierMessages;

  Future<bool> locateSearchMessage(String messageId) async {
    final conversation = activeConversation;
    final generation = ++_searchNavigationGeneration;
    bool isCurrent() =>
        generation == _searchNavigationGeneration &&
        identical(activeConversation, conversation);
    const limit = 50;
    try {
      final before = await _store.reader.messages(
        conversation.id,
        throughMessageId: messageId,
        includeMessageId: messageId,
        limit: limit,
      );
      if (!isCurrent()) return false;
      if (before.isEmpty || before.last.id != messageId) {
        throw StateError('这条消息已不存在，请重新搜索');
      }
      final after = await _store.reader.messages(
        conversation.id,
        after: before.last,
        limit: limit,
      );
      if (!isCurrent()) return false;
      conversation.searchMessages = [...before, ...after];
      conversation.searchMessageId = messageId;
      conversation.searchHasEarlier = before.length == limit;
      conversation.searchHasLater = after.length == limit;
      _searchWindows[conversation.id] = conversation;
      _conversationChanged();
      return true;
    } on Object {
      if (!isCurrent()) return false;
      rethrow;
    }
  }

  void cancelSearchNavigation() => _searchNavigationGeneration++;

  Future<void> loadVisibleEarlierMessages() async {
    if (!hasSearchWindow) return loadEarlierMessages();
    await _loadSearchPage(earlier: true);
  }

  Future<void> loadVisibleLaterMessages() => _loadSearchPage(earlier: false);

  Future<void> _loadSearchPage({required bool earlier}) async {
    final conversation = activeConversation;
    final window = conversation.searchMessages;
    if (window == null ||
        conversation.loadingSearchPage ||
        !(earlier
            ? conversation.searchHasEarlier
            : conversation.searchHasLater))
      return;
    conversation.loadingSearchPage = true;
    try {
      final page = await _store.reader.messages(
        conversation.id,
        before: earlier ? window.first : null,
        after: earlier ? null : window.last,
      );
      if (!identical(conversation.searchMessages, window)) return;
      if (earlier) {
        window.insertAll(0, page);
        conversation.searchHasEarlier =
            page.length == ConversationReader.messagePageSize;
      } else {
        window.addAll(page);
        conversation.searchHasLater =
            page.length == ConversationReader.messagePageSize;
      }
    } finally {
      conversation.loadingSearchPage = false;
      _conversationChanged();
    }
  }

  void leaveSearchWindow() {
    cancelSearchNavigation();
    _searchWindows.remove(activeConversation.id);
    activeConversation.searchMessages = null;
    activeConversation.searchMessageId = null;
    _conversationChanged();
  }

  void _restoreSearchWindow(Conversation conversation) {
    final saved = _searchWindows[conversation.id];
    if (saved == null) return;
    conversation.searchMessages = saved.searchMessages;
    conversation.searchMessageId = saved.searchMessageId;
    conversation.searchHasEarlier = saved.searchHasEarlier;
    conversation.searchHasLater = saved.searchHasLater;
    _searchWindows[conversation.id] = conversation;
  }
}
