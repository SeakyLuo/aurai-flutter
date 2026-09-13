import 'package:sqflite/sqflite.dart';

import '../domain/message_sender.dart';

const messageSenderSchema = [
  '''CREATE TABLE message_senders (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    kind TEXT NOT NULL
  )''',
  "INSERT INTO message_senders VALUES ('user:local', '你', 'user')",
  "INSERT INTO message_senders VALUES ('agent:aurai', 'Aurai', 'agent')",
];

Future<void> migrateMessageSenders(Database db) async {
  final batch = db.batch();
  for (final statement in messageSenderSchema) {
    batch.execute(statement);
  }
  batch.execute(
    'ALTER TABLE messages ADD COLUMN sender_id TEXT REFERENCES message_senders(id)',
  );
  batch.execute(
    '''UPDATE messages SET sender_id = CASE role
      WHEN 'user' THEN ? ELSE ? END''',
    [MessageSender.localUser.id, MessageSender.aurai.id],
  );
  await batch.commit(noResult: true);
}

const messageSenderAvatarColumns = [
  "ALTER TABLE message_senders ADD COLUMN avatar_icon TEXT NOT NULL DEFAULT 'person'",
  "ALTER TABLE message_senders ADD COLUMN avatar_color TEXT NOT NULL DEFAULT 'violet'",
  'ALTER TABLE message_senders ADD COLUMN avatar_path TEXT',
  'ALTER TABLE message_senders ADD COLUMN archived INTEGER NOT NULL DEFAULT 0',
];

Future<void> migrateAuraiAvatar(Database db) async {
  await db.update(
    'message_senders',
    {'avatar_icon': 'app_logo', 'avatar_path': null},
    where: 'id = ?',
    whereArgs: [MessageSender.aurai.id],
  );
}
