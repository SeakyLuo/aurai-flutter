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

  static MessageSender _localUser = const MessageSender(
    id: 'user:local',
    name: '你',
    kind: MessageSenderKind.user,
  );
  static MessageSender get localUser => _localUser;

  static void setLocalUserName(String name) {
    _localUser = MessageSender(
      id: _localUser.id,
      name: name.isEmpty ? '你' : name,
      kind: _localUser.kind,
      avatarIcon: _localUser.avatarIcon,
      avatarColor: _localUser.avatarColor,
      avatarPath: _localUser.avatarPath,
      archived: _localUser.archived,
    );
  }

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
