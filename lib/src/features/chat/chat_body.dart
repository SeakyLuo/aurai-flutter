part of 'chat_page.dart';

extension _ChatBody on _ChatPageState {
  Widget _buildChatBody(
    BuildContext context,
    List<ChatTimelineEntry> timeline,
    bool showWelcome,
    bool isGroup,
  ) {
    final controller = widget.controller;
    final active = controller.activeConversation;
    final conversationId = active.id;
    return QuoteFocusBackground(
      active: _quoteFocused,
      onCancel: () => _quoteMessage(null),
      child: GroupAnnouncementBanner(
        controller: controller,
        groupId: _conversationId,
        onLocate: (id) => _pinSplitKey.currentState!.open(id),
        builder: (context, announcementHeight) {
          final top =
              View.of(context).padding.top / View.of(context).devicePixelRatio +
              ChatHeader.toolbarHeight +
              announcementHeight;
          final bottom = MediaQuery.paddingOf(context).bottom;
          return Stack(
            children: [
              if (showWelcome)
                const Positioned.fill(child: SearchAuroraBackground()),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ScrollAwareJumpStack(
                    messages: controller.messages,
                    readThrough: isGroup
                        ? (
                            at: controller.activeConversation.groupReadAt,
                            id: controller.activeConversation.groupReadId,
                          )
                        : null,
                    acknowledgedRunId:
                        !isGroup &&
                            controller.pendingQuestion?.conversationId ==
                                _conversationId
                        ? controller.activeConversation.activeRunId
                        : null,
                    atBottom:
                        (_followOutput || !_contentBelow) &&
                        !(controller.hasSearchWindow &&
                            controller.activeConversation.searchHasLater),
                    key: ValueKey(_conversationId),
                    children: [
                      Positioned.fill(
                        child: timeline.isEmpty && isGroup
                            ? const SizedBox.expand()
                            : timeline.isEmpty
                            ? ChatEmptyState(
                                showWelcome: showWelcome,
                                temporary: active.isTemporary,
                                personalized: active.usesPersonalization,
                                onPersonalizationChanged:
                                    controller.setTemporaryChatPersonalization,
                                top: top,
                                bottom: bottom,
                                onUseExample: _useExample,
                              )
                            : isGroup &&
                                  controller.visibleMessages.every(
                                    (message) => message.isSystem,
                                  )
                            ? _groupIntroduction(timeline, top, bottom)
                            : RepaintBoundary(
                                key: PageStorageKey(
                                  'conversation:$_conversationId',
                                ),
                                child: ChatViewport(
                                  key: _viewportKey,
                                  entries: timeline,
                                  showScrollbar: true,
                                  alignShortContentToTop: active.isPersonalChat,
                                  onScrollToLatest: _scrollToBottom,
                                  bookmark: _scrollBookmarks[_conversationId],
                                  followOutput: _followOutput && !_quoteFocused,
                                  sentMessageId: _sentMessageId,
                                  sentMessageTop:
                                      top + 8 - MessageItem.userTopMargin,
                                  onVisibleEntriesChanged: _scheduleMarkRead,
                                  onContentBelowChanged: (value) {
                                    if (mounted &&
                                        _conversationId == conversationId) {
                                      _updateChatBody(
                                        () => _contentBelow = value,
                                      );
                                    }
                                  },
                                  padding: EdgeInsets.only(
                                    top: top + 12,
                                    bottom: bottom + 56,
                                  ),
                                  hasEarlierMessages:
                                      controller.visibleHasEarlier,
                                  hasLaterMessages:
                                      controller.hasSearchWindow &&
                                      controller
                                          .activeConversation
                                          .searchHasLater,
                                  loadLaterMessages:
                                      controller.loadVisibleLaterMessages,
                                  loadEarlierMessages:
                                      controller.loadVisibleEarlierMessages,
                                  onUserScroll: _dismissReachedUnread,
                                  onBookmark: (bookmark) {
                                    _recordQuoteBookmark(
                                      conversationId,
                                      bookmark,
                                    );
                                  },
                                  onFollowOutputChanged: (value) {
                                    if (mounted)
                                      _updateChatBody(
                                        () => _followOutput =
                                            controller.hasSearchWindow
                                            ? false
                                            : value,
                                      );
                                  },
                                  summaryOwners: chatSummaryOwners(controller),
                                ),
                              ),
                      ),
                      if (controller.changingConversation)
                        Positioned.fill(
                          child: ColoredBox(
                            color: Theme.of(
                              context,
                            ).colorScheme.surface.withValues(alpha: 0.81),
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: const ThinkingIndicator(label: '正在打开会话'),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        left: 12,
                        right: 16,
                        bottom: bottom + 8,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (isGroup)
                              Expanded(child: _groupStatus(active))
                            else
                              Expanded(child: _privateStatus(active)),
                            const SizedBox(width: 8),
                            JumpToBottomButton(
                              visible:
                                  !_followOutput &&
                                  (_contentBelow ||
                                      (controller.hasSearchWindow &&
                                          controller
                                              .activeConversation
                                              .searchHasLater)) &&
                                  timeline.isNotEmpty,
                              onPressed: _scrollToBottom,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _unreadPositionHint(top),
            ],
          );
        },
      ),
    );
  }
}
