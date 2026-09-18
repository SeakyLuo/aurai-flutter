import 'package:sqflite/sqflite.dart';

const messageQuickReplySchema = [
  '''CREATE TABLE message_quick_replies (
    message_id TEXT PRIMARY KEY REFERENCES messages(id) ON DELETE CASCADE,
    parent_message_id TEXT NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    actor_id TEXT NOT NULL REFERENCES message_senders(id),
    reply_key TEXT NOT NULL,
    UNIQUE(parent_message_id, actor_id, reply_key)
  )''',
  'CREATE INDEX message_quick_reply_parent ON message_quick_replies(parent_message_id, message_id)',
];

Future<void> migrateMultipleQuickReplies(Database db) async {
  await db.execute(
    'ALTER TABLE message_quick_replies RENAME TO old_quick_replies',
  );
  await db.execute('DROP INDEX message_quick_reply_parent');
  for (final statement in messageQuickReplySchema) {
    await db.execute(statement);
  }
  await db.execute(
    'INSERT INTO message_quick_replies '
    '(message_id, parent_message_id, actor_id, reply_key) '
    'SELECT message_id, parent_message_id, actor_id, reply_key FROM old_quick_replies',
  );
  await db.execute('DROP TABLE old_quick_replies');
}
