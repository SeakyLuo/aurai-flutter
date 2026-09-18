part of 'chat_controller.dart';

extension ConversationRunPersistence on ChatController {
  Future<void> _persistRun(Conversation conversation) =>
      _store.writer.save(conversation, makeActive: false, saveRuntime: true);

  void _notifyRun(Conversation conversation) {
    if (conversation.kind == ConversationKind.group &&
        _viewConversation.id == conversation.id &&
        !identical(_viewConversation, conversation)) {
      final messages =
          {
            for (final message in _viewConversation.messages)
              message.id: message,
            for (final message in conversation.messages) message.id: message,
          }.values.toList()..sort((a, b) {
            final order = a.createdAt.compareTo(b.createdAt);
            return order == 0 ? a.id.compareTo(b.id) : order;
          });
      _viewConversation.messages
        ..clear()
        ..addAll(messages);
    }
    _updateConversationList(conversation);
    _conversationChanged();
  }
}
