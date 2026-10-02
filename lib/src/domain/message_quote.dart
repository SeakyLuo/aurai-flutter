class MessageQuote {
  MessageQuote({
    required this.messageId,
    required this.senderId,
    required this.text,
    this.audience,
    this.excludedAudience,
    this.markdown = true,
  });
  final String messageId;
  final String senderId;
  final String text;
  final bool markdown;
  final List<String>? audience;
  final List<String>? excludedAudience;
  bool canView(String viewer) =>
      (audience == null || audience!.contains(viewer)) &&
      !(excludedAudience?.contains(viewer) ?? false);
  String textFor(String viewer) => canView(viewer) ? text : '你没有查看这条消息的权限';
  late String senderName;

  Map<String, Object?> toJson() => {
    'messageId': messageId,
    'senderId': senderId,
    'text': text,
    'markdown': markdown,
    if (audience != null) 'audience': audience,
    if (excludedAudience != null) 'excludedAudience': excludedAudience,
  };
  factory MessageQuote.fromJson(Map<String, Object?> json) => MessageQuote(
    messageId: json['messageId'] as String,
    senderId: json['senderId'] as String,
    text: json['text'] as String,
    markdown: json['markdown'] != false,
    audience: (json['audience'] as List?)?.cast<String>(),
    excludedAudience: (json['excludedAudience'] as List?)?.cast<String>(),
  );
}
