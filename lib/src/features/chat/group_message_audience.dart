part of 'chat_controller.dart';

extension GroupMessageAudience on ChatController {
  List<AgentMessage> _privateHistory(
    Iterable<AgentMessage> messages,
    String viewerId,
  ) => [
    for (final message in messages)
      if (message.quote case final quote?)
        message.withSender(
          message.sender,
          quote: MessageQuote(
            messageId: quote.messageId,
            senderId: quote.senderId,
            text: quote.textFor(viewerId),
            audience: quote.audience,
          )..senderName = quote.senderName,
        )
      else
        message,
  ];

  List<String>? _messageAudience(
    Map<String, Object?> message,
    Iterable<String> members,
    String senderId,
  ) {
    final raw = message['audience'];
    if (raw == null) return null;
    if (raw is! List || raw.isEmpty || raw.any((id) => id is! String)) {
      throw ArgumentError('可见范围必须是非空的群成员列表');
    }
    final audience = {...raw.cast<String>(), senderId};
    if (audience.any((id) => !members.contains(id))) {
      throw ArgumentError('可见范围只能包含当前群成员');
    }
    final mentions = (message['mentionIds'] as List).cast<String>();
    if (mentions.any((id) => !audience.contains(id))) {
      throw ArgumentError('只能 @ 可见范围内的群成员');
    }
    return audience.toList();
  }

  void _checkQuoteAudience(List<String>? sourceAudience, String senderId) {
    if (sourceAudience == null) return;
    if (!sourceAudience.contains(senderId)) {
      throw ArgumentError('你无权引用这条消息');
    }
  }
}
