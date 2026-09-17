part of 'chat_controller.dart';

extension ConversationSearchNavigation on ChatController {
  List<AgentMessage> get visibleMessages {
    final conversation = activeConversation;
    final window = conversation.searchMessages;
    if (window == null)
      return messages.where((message) => message.quickReplyToId == null).toList();
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
    return combined
        .where((message) => message.quickReplyToId == null)
        .toList();
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
