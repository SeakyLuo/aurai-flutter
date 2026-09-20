part of 'chat_page.dart';

extension _ChatSearchNavigation on _ChatPageState {
  Future<void> _locateSearchMessage(String messageId) async {
    final controller = widget.controller;
    final conversation = controller.activeConversation;
    try {
      if (!await controller.locateSearchMessage(messageId)) return;
      if (!mounted || !identical(controller.activeConversation, conversation))
        return;
      _focusNode.unfocus();
      _positionSearchResult(messageId);
    } on Object catch (caughtError) {
      if (mounted && identical(controller.activeConversation, conversation)) {
        _scrollToBottom();
        _imageNotice('无法定位这条消息，请重新搜索：${errorMessage(caughtError)}');
      }
    }
  }

  void _applySearchPosition(String messageId) {
    _followOutput = false;
    _sentMessageId = null;
    _scrollBookmarks[_conversationId] = ChatScrollBookmark(
      messageId,
      .15,
      false,
    );
    _viewportKey = GlobalKey<ChatViewportState>();
  }
}
