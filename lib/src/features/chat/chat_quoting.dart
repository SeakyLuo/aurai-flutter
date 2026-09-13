part of 'chat_page.dart';

extension _ChatQuoting on _ChatPageState {
  Future<void> _recallMessage(AgentMessage message) async {
    try {
      await widget.controller.recallMessage(message);
    } on Object {
      if (mounted) _imageNotice('撤回失败，请重试');
    }
  }

  Future<void> _quoteMessage(AgentMessage? message) async {
    final conversation = widget.controller.activeConversation;
    try {
      await widget.controller.setDraftQuote(message);
      if (mounted &&
          message != null &&
          identical(conversation, widget.controller.activeConversation))
        _focusNode.requestFocus();
    } on Object {
      if (mounted) _imageNotice('引用保存失败，请重试');
    }
  }

  Future<void> _openQuotedMessage(String id) async {
    final controller = widget.controller;
    final conversation = controller.activeConversation;
    try {
      if (!await controller.locateSearchMessage(id)) return;
      if (!mounted || !identical(conversation, controller.activeConversation))
        return;
      _focusNode.unfocus();
      _positionSearchResult(id);
    } on Object {
      if (mounted) _imageNotice('原消息已不存在');
    }
  }
}
