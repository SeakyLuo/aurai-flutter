import 'package:sqflite/sqflite.dart';
import 'message_sender_schema.dart';

const groupChatTables = [
  '''CREATE TABLE ai_profiles (
    sender_id TEXT PRIMARY KEY REFERENCES message_senders(id),
    description TEXT NOT NULL DEFAULT '',
    instructions TEXT NOT NULL DEFAULT '',
    provider TEXT,
    model TEXT,
    base_url TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    CHECK ((provider IS NULL AND model IS NULL AND base_url IS NULL) OR
      (provider IS NOT NULL AND model IS NOT NULL AND base_url IS NOT NULL))
  )''',
  '''INSERT INTO ai_profiles (sender_id, created_at, updated_at)
    VALUES ('agent:aurai', 0, 0)''',
  '''CREATE TABLE conversation_members (
    conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    sender_id TEXT NOT NULL REFERENCES message_senders(id),
    position INTEGER NOT NULL,
    joined_at INTEGER NOT NULL,
    left_at INTEGER,
    PRIMARY KEY (conversation_id, sender_id)
  )''',
  '''CREATE TABLE message_recipients (
    message_id TEXT NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    sender_id TEXT NOT NULL REFERENCES ai_profiles(sender_id),
    PRIMARY KEY (message_id, sender_id)
  )''',
  'CREATE INDEX ai_profile_order ON ai_profiles(created_at DESC, sender_id DESC)',
  'CREATE INDEX member_sender ON conversation_members(sender_id, left_at, conversation_id)',
  'CREATE INDEX recipient_sender ON message_recipients(sender_id, message_id)',
  'CREATE INDEX run_sender ON agent_runs(conversation_id, sender_id, started_at DESC, id DESC)',
  // Insert-time membership also covers legacy imports and new single chats.
  '''CREATE TRIGGER direct_conversation_members AFTER INSERT ON conversations
    WHEN NEW.kind = 'direct'
    BEGIN
      INSERT INTO conversation_members VALUES
        (NEW.id, 'user:local', 0, NEW.created_at, NULL),
        (NEW.id, NEW.default_sender_id, 1, NEW.created_at, NULL);
    END''',
];

Future<void> migrateGroupChats(Database db) async {
  final batch = db.batch();
  for (final statement in messageSenderAvatarColumns) {
    batch.execute(statement);
  }
  batch.execute(
    "ALTER TABLE conversations ADD COLUMN kind TEXT NOT NULL DEFAULT 'direct'",
  );
  batch.execute(
    'ALTER TABLE conversations ADD COLUMN default_sender_id TEXT REFERENCES message_senders(id)',
  );
  batch.execute("UPDATE conversations SET default_sender_id = 'agent:aurai'");
  batch.execute(
    'ALTER TABLE agent_runs ADD COLUMN sender_id TEXT REFERENCES message_senders(id)',
  );
  batch.execute("UPDATE agent_runs SET sender_id = 'agent:aurai'");
  batch.execute('ALTER TABLE agent_runs ADD COLUMN configuration_json TEXT');
  for (final statement in groupChatTables) {
    batch.execute(statement);
  }
  batch.execute(
    '''INSERT INTO conversation_members
    SELECT id, 'user:local', 0, created_at, NULL FROM conversations
    UNION ALL SELECT id, 'agent:aurai', 1, created_at, NULL FROM conversations''',
  );
  batch.execute('''INSERT INTO message_recipients
    SELECT id, 'agent:aurai' FROM messages WHERE role = 'user' ''');
  await batch.commit(noResult: true);
}

const temporaryAiColumn =
    'ALTER TABLE ai_profiles ADD COLUMN is_temporary INTEGER NOT NULL DEFAULT 0 CHECK (is_temporary IN (0, 1))';
