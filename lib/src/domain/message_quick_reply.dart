class MessageQuickReply {
  const MessageQuickReply({
    required this.id,
    required this.senderId,
    required this.key,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String key;
  final String text;
  final DateTime createdAt;
}
