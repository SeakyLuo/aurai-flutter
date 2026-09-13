class MessageQuote {
  MessageQuote({
    required this.messageId,
    required this.senderId,
    required this.text,
  });
  final String messageId;
  final String senderId;
  final String text;
  late String senderName;

  Map<String, Object?> toJson() => {
    'messageId': messageId,
    'senderId': senderId,
    'text': text,
  };
  factory MessageQuote.fromJson(Map<String, Object?> json) => MessageQuote(
    messageId: json['messageId'] as String,
    senderId: json['senderId'] as String,
    text: json['text'] as String,
  );
}
