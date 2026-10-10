part of 'chat_page.dart';

extension _ChatQuoting on _ChatPageState {
  bool get _quoteFocused =>
      _editing == null &&
      widget.controller.activeConversation.draftQuote != null;

  Widget _buildQuoteComposer(bool isGroup) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (_quoteFocused)
        QuoteFocusMessage(
          key: _quoteFocusKey,
          composerKey: _quoteComposerKey,
          topInset:
              MediaQuery.paddingOf(context).top + ChatHeader.toolbarHeight,
          quote: widget.controller.activeConversation.draftQuote!,
          visual: _quoteVisual,
          onCancel: () => _quoteMessage(null),
        ),
      KeyedSubtree(key: _quoteComposerKey, child: _buildChatComposer(isGroup)),
    ],
  );

  void _syncQuotePosition() {
    if (_conversationId != widget.controller.activeConversation.id) {
      _quoteBookmark = null;
      _quoteVisual = null;
      return;
    }
    if (!_quoteFocused) _quoteVisual = null;
    if (_quoteFocused || _quoteBookmark == null) return;
    final bookmark = _quoteBookmark!;
    final conversationId = _conversationId;
    _quoteBookmark = null;
    _sentMessageId = bookmark.replyAnchorId;
    _followOutput = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _conversationId == conversationId) {
        _viewportKey.currentState?.restoreBookmark(bookmark);
      }
    });
  }

  void _recordQuoteBookmark(
    String conversationId,
    ChatScrollBookmark bookmark,
  ) {
    if (_editing != null) return;
    if (_quoteFocused) {
      _quoteBookmark ??= ChatScrollBookmark(
        bookmark.messageId,
        bookmark.alignment,
        false,
        bookmark.replyAnchorId,
      );
    } else {
      _scrollBookmarks[conversationId] = bookmark;
    }
  }

  Future<void> _reeditRecalledMessage(AgentMessage message) async {
    if (_editing != null) return;
    if (_textController.text.isNotEmpty) {
      _imageNotice('请先发送或清空当前草稿，再重新编辑', kind: ToastKind.warning);
      return;
    }
    final conversation = widget.controller.activeConversation;
    try {
      await widget.controller.restoreRecalledDraft(message);
      if (mounted &&
          identical(conversation, widget.controller.activeConversation)) {
        _focusNode.requestFocus();
      }
    } on Object catch (error) {
      if (mounted) _imageNotice(errorMessage(error), kind: ToastKind.error);
    }
  }

  Future<void> _recallMessage(AgentMessage message) async {
    try {
      await widget.controller.recallMessage(message);
    } on Object catch (caughtError) {
      if (mounted)
        _imageNotice(
          '撤回失败，请重试：${errorMessage(caughtError)}',
          kind: ToastKind.error,
        );
    }
  }

  Future<void> _quoteMessage(
    AgentMessage? message, {
    String? selectedText,
    QuoteFocusVisual? visual,
  }) async {
    final conversation = widget.controller.activeConversation;
    try {
      if (message == null && _quoteFocused) {
        if (_quoteReturning) return;
        _quoteReturning = true;
        try {
          _focusNode.unfocus();
          await _quoteFocusKey.currentState!.returnToSource();
        } finally {
          _quoteReturning = false;
        }
        if (!mounted ||
            !identical(conversation, widget.controller.activeConversation))
          return;
      }
      if (message != null && !_quoteFocused) {
        final bookmark = _scrollBookmarks[conversation.id];
        if (bookmark != null) {
          _quoteBookmark = ChatScrollBookmark(
            bookmark.messageId,
            bookmark.alignment,
            false,
            bookmark.replyAnchorId,
          );
        }
      }
      _quoteVisual = message == null ? null : visual;
      if (message != null && conversation.kind == ConversationKind.group) {
        final members = await widget.controller.groupStore.noticeMembers(
          conversation.id,
        );
        if (!mounted ||
            !identical(conversation, widget.controller.activeConversation))
          return;
        final byId = {for (final member in members) member.id: member};
        final audience = message.audience;
        final excluded = message.excludedAudience;
        _updateDraftVisibility(() {
          _draftVisibility[conversation.id] = DraftVisibility(
            audience != null
                ? DraftVisibilityMode.included
                : excluded != null && excluded.isNotEmpty
                ? DraftVisibilityMode.excluded
                : DraftVisibilityMode.everyone,
            [
              for (final id in audience ?? excluded ?? <String>[])
                if (id != MessageSender.localUser.id) byId[id]!,
            ],
          );
        });
      }
      await widget.controller.setDraftQuote(
        message,
        selectedText: selectedText,
      );
      if (mounted &&
          identical(conversation, widget.controller.activeConversation)) {
        _updateChatBody(() {});
      }
      if (mounted &&
          message != null &&
          identical(conversation, widget.controller.activeConversation)) {
        _focusNode.requestFocus();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _quoteFocused && _focusNode.hasFocus) {
            SystemChannels.textInput.invokeMethod<void>('TextInput.show');
          }
        });
      }
    } on Object catch (caughtError) {
      if (mounted)
        _imageNotice(
          '引用保存失败，请重试：${errorMessage(caughtError)}',
          kind: ToastKind.error,
        );
    }
  }

  Future<void> _openQuotedMessage(String id) =>
      _pinSplitKey.currentState!.open(id, pinned: false);
}
