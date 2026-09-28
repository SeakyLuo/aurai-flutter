part of 'chat_page.dart';

extension _ChatBranching on _ChatPageState {
  Future<void> _createConversationBranch(AgentMessage message) async {
    _focusNode.unfocus();
    try {
      await widget.controller.createConversationBranch(message);
    } on Object catch (error) {
      if (mounted) {
        final message = errorMessage(error);
        ScaffoldMessenger.of(context).showGlassSnackBar(
          SnackBar(content: Text(message == '任务已停止' ? '已取消' : message)),
        );
      }
    }
  }
}
