part of 'chat_controller.dart';

extension MessageQuoteActions on ChatController {
  Future<void> setDraftQuote(AgentMessage? message) async {
    final conversation = activeConversation;
    MessageQuote? quote;
    if (message != null) {
      quote = MessageQuote(
        messageId: message.id,
        senderId: message.senderId,
        text: [
          if (message.images.isNotEmpty) '[图片]',
          for (final file in message.files) '[文件] ${file.name}',
          if (message.text.isNotEmpty)
            String.fromCharCodes(message.text.runes.take(1000)),
        ].join(' '),
      )..senderName = message.sender?.name ?? MessageSender.localUser.name;
    }
    conversation.draftQuote = quote;
    _conversationChanged();
    await _store.writer.save(conversation, makeActive: false);
  }
}
