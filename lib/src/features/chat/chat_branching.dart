part of 'chat_page.dart';

extension _ChatBranching on _ChatPageState {
  Future<void> _createConversationBranch(AgentMessage message) async {
    _focusNode.unfocus();
    try {
      await widget.controller.createConversationBranch(message);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showGlassSnackBar(const SnackBar(content: Text('已创建分支')));
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showGlassSnackBar(SnackBar(content: Text(errorMessage(error))));
      }
    }
  }
}
