part of 'chat_page.dart';

extension _ChatPinnedMessage on _ChatPageState {
  Widget _buildPinnedMessage(BuildContext context, AgentMessage message) {
    final entries = buildChatTimeline(
      widget.controller,
      singleMessage: message,
      onEdit: _beginMessageEdit,
      onRecall: _recallMessage,
      onQuote: _editing == null
          ? (message, {selectedText, visual}) async {
              final route = ModalRoute.of(context)!;
              if (route is PopupRoute) {
                Navigator.pop(context);
                await route.completed;
              }
              if (!mounted) return;
              await _quoteMessage(
                message,
                selectedText: selectedText,
                visual: visual,
              );
            }
          : null,
      onMention: _editing == null ? _mentionMember : null,
      onOpenQuote: _openQuotedMessage,
      onQuickReply: _sendQuickReply,
      onRetry: _retryFailedMessage,
    );
    return entries
        .firstWhere((entry) => entry.id == message.id)
        .builder(context);
  }
}
