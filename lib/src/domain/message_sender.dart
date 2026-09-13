class MessageSender {
  const MessageSender({
    required this.id,
    required this.name,
    required this.kind,
    this.avatarIcon = 'person',
    this.avatarColor = 'violet',
    this.avatarPath,
    this.archived = false,
  });

  final String id;
  final String name;
  final MessageSenderKind kind;
  final String avatarIcon;
  final String avatarColor;
  final String? avatarPath;
  final bool archived;

  static const localUser = MessageSender(
    id: 'user:local',
    name: '你',
    kind: MessageSenderKind.user,
  );
  static const aurai = MessageSender(
    id: 'agent:aurai',
    name: 'Aurai',
    kind: MessageSenderKind.agent,
    avatarIcon: 'app_logo',
  );

  factory MessageSender.fromRow(Map<String, Object?> row) => MessageSender(
    id: row['id'] as String,
    name: row['name'] as String,
    kind: MessageSenderKind.values.byName(row['kind'] as String),
    avatarIcon: row['avatar_icon'] as String,
    avatarColor: row['avatar_color'] as String,
    avatarPath: row['avatar_path'] as String?,
    archived: row['archived'] == 1,
  );
}

enum MessageSenderKind { user, agent }
