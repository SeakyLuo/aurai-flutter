class MessageQuote {
  MessageQuote({
    required this.messageId,
    required this.senderId,
    required this.text,
    this.audience,
  });
  final String messageId;
  final String senderId;
  final String text;
  final List<String>? audience;
  bool canView(String viewer) => audience == null || audience!.contains(viewer);
  String textFor(String viewer) => canView(viewer) ? text : '你没有查看这条消息的权限';
  late String senderName;

  Map<String, Object?> toJson() => {
    'messageId': messageId,
    'senderId': senderId,
    'text': text,
    if (audience != null) 'audience': audience,
  };
  factory MessageQuote.fromJson(Map<String, Object?> json) => MessageQuote(
    messageId: json['messageId'] as String,
    senderId: json['senderId'] as String,
    text: json['text'] as String,
    audience: (json['audience'] as List?)?.cast<String>(),
  );
}
