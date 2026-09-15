part of 'chat_page.dart';

extension _ChatQuoting on _ChatPageState {
  Future<void> _reeditRecalledMessage(AgentMessage message) async {
    if (_editing != null) return;
    if (_textController.text.isNotEmpty) {
      _imageNotice('请先发送或清空当前草稿，再重新编辑');
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
      if (mounted) _imageNotice(errorMessage(error));
    }
  }

  Future<void> _recallMessage(AgentMessage message) async {
    try {
      await widget.controller.recallMessage(message);
    } on Object catch (caughtError) {
      if (mounted) _imageNotice('撤回失败，请重试：${errorMessage(caughtError)}');
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
    } on Object catch (caughtError) {
      if (mounted) _imageNotice('引用保存失败，请重试：${errorMessage(caughtError)}');
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
    } on Object catch (caughtError) {
      if (mounted) _imageNotice('原消息已不存在：${errorMessage(caughtError)}');
    }
  }
}
