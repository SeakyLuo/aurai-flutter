part of 'chat_page.dart';

extension _ChatQuoting on _ChatPageState {
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
  }) async {
    final conversation = widget.controller.activeConversation;
    try {
      await widget.controller.setDraftQuote(
        message,
        selectedText: selectedText,
      );
      if (mounted &&
          message != null &&
          identical(conversation, widget.controller.activeConversation))
        _focusNode.requestFocus();
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
