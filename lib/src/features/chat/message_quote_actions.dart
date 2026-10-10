part of 'chat_controller.dart';

extension MessageQuoteActions on ChatController {
  Future<void> setDraftQuote(
    AgentMessage? message, {
    String? selectedText,
  }) async {
    final conversation = activeConversation;
    MessageQuote? quote;
    if (message != null) {
      quote =
          MessageQuote(
              messageId: message.id,
              senderId: message.senderId,
              audience: message.audience,
              excludedAudience: message.excludedAudience,
              excerpt: selectedText != null,
              markdown:
                  selectedText == null &&
                  message.role == AgentMessageRole.assistant &&
                  (!message.isGroupMessage || message.markdown),
              text:
                  selectedText ??
                  [
                    if (message.images.isNotEmpty) '[图片]',
                    if (message.interactive != null)
                      '[${message.interactive!.isQuestionnaire
                          ? '问卷'
                          : message.interactive!.isVote
                          ? '投票'
                          : '互动消息'}] ${message.interactive!.title}',
                    if (message.htmlGame != null) '[小程序]',
                    for (final file in message.files) '[文件] ${file.name}',
                    if (message.text.isNotEmpty)
                      String.fromCharCodes(message.text.runes.take(1000)),
                  ].join(' '),
            )
            ..senderName = message.sender?.name ?? MessageSender.localUser.name
            ..resolveSource(message);
    }
    conversation.draftQuote = quote;
    _conversationChanged();
    await _store.writer.save(
      conversation,
      makeActive: false,
      saveDraft: true,
      saveMessages: false,
    );
  }
}
