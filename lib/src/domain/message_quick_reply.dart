class MessageQuickReply {
  const MessageQuickReply({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.key,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String key;
  final DateTime createdAt;
}
