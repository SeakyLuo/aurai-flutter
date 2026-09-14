import 'contact_relationships.dart';
import '../html_games/html_game_schema.dart';
import 'ai_identity_schema.dart';
import 'group_participation.dart';
import 'group_creation_migration.dart';
import '../skills/skill_schema.dart';
import 'message_sender_schema.dart';
import 'group_chat_schema.dart';
import 'package:sqflite/sqflite.dart';
import '../memory/memory_controller.dart';

Future<Database> openConversationDatabase() async => openDatabase(
  '${await getDatabasesPath()}/aurai.sqlite',
  version: 24,
  onConfigure: (db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    await db.rawQuery('PRAGMA journal_mode = WAL');
  },
  onUpgrade: (db, oldVersion, newVersion) async {
    if (oldVersion < 10) await migrateMessageSenders(db);
    if (oldVersion < 11) await migrateGroupChats(db);
    if (oldVersion < 12) await db.execute(temporaryAiColumn);
    if (oldVersion < 9 && oldVersion >= 4) {
      await db.execute('DROP TABLE forgotten_memories');
    }
    if (oldVersion < 9) {
      await db.execute(
        "ALTER TABLE attachments ADD COLUMN kind TEXT NOT NULL DEFAULT 'image'",
      );
      await db.execute('ALTER TABLE attachments ADD COLUMN display_name TEXT');
      await db.execute('ALTER TABLE attachments ADD COLUMN byte_size INTEGER');
    }
    if (oldVersion < 8) {
      await db.execute('ALTER TABLE model_turns ADD COLUMN response_json TEXT');
    }
    if (oldVersion == 6) {
      await db.execute(
        "ALTER TABLE skills ADD COLUMN icon TEXT NOT NULL DEFAULT 'skill'",
      );
    }
    if (oldVersion < 6) {
      final batch = db.batch();
      for (final statement in skillSchema) {
        batch.execute(statement);
      }
      await batch.commit(noResult: true);
    }
    if (oldVersion < 5) {
      await db.execute(
        'ALTER TABLE conversations ADD COLUMN scheduled_task INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE conversations ADD COLUMN archived INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'CREATE INDEX conversation_archive_order ON conversations(archived, pinned DESC, updated_at DESC, id DESC)',
      );
    }
    if (oldVersion < 2) {
      final batch = db.batch();
      for (final statement in memorySchema) {
        batch.execute(statement);
      }
      await batch.commit(noResult: true);
    }
    if (oldVersion < 13) await migrateAiIdentities(db);
    if (oldVersion < 14) {
      // Some version 13 databases already contain the group creation column.
      final columns = await db.rawQuery('PRAGMA table_info(conversations)');
      if (!columns.any((column) => column['name'] == 'creation_member_ids')) {
        await db.execute(
          'ALTER TABLE conversations ADD COLUMN creation_member_ids TEXT',
        );
      }
    }
    if (oldVersion < 15) await migrateGroupCreationData(db);
    if (oldVersion < 16) await migrateAuraiAvatar(db);
    if (oldVersion < 17) {
      await db.execute('ALTER TABLE messages ADD COLUMN quote_json TEXT');
      await db.execute(
        'ALTER TABLE conversations ADD COLUMN draft_quote_json TEXT',
      );
    }
    if (oldVersion < 19)
      await db.execute('ALTER TABLE messages ADD COLUMN interactive_json TEXT');
    if (oldVersion < 18) await db.execute(groupParticipationSchema);
    if (oldVersion < 20) {
      for (final statement in htmlGameSchema) {
        await db.execute(statement);
      }
    }
    if (oldVersion >= 20 && oldVersion < 22) {
      await db.execute(
        "ALTER TABLE html_games ADD COLUMN display_mode TEXT NOT NULL DEFAULT 'hybrid'",
      );
    }
    if (oldVersion >= 20 && oldVersion < 23) {
      await db.execute(
        'ALTER TABLE html_games ADD COLUMN stateful INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 21) {
      for (final statement in contactRelationshipSchema) {
        await db.execute(statement);
      }
    }
    if (oldVersion < 24) await migrateAuraiDescription(db);
  },
  onCreate: (db, version) async {
    final batch = db.batch();
    for (final statement in [
      ..._schema,
      ...htmlGameSchema,
      ...groupChatTables,
      groupParticipationSchema,
      temporaryAiColumn,
      ...contactRelationshipSchema,
      ...skillSchema,
      ...memorySchema,
    ]) {
      batch.execute(statement);
    }
    await batch.commit(noResult: true);
    await migrateAiIdentities(db);
    await migrateAuraiAvatar(db);
    await migrateAuraiDescription(db);
  },
);

const _schema = [
  ...messageSenderSchema,
  ...messageSenderAvatarColumns,
  '''CREATE TABLE app_state (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
  )''',
  '''CREATE TABLE conversations (
    id TEXT PRIMARY KEY,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    title TEXT NOT NULL,
    kind TEXT NOT NULL DEFAULT 'direct',
    default_sender_id TEXT NOT NULL DEFAULT 'agent:aurai' REFERENCES message_senders(id),
    preview TEXT,
    creation_member_ids TEXT,
    draft_quote_json TEXT,
    pinned INTEGER NOT NULL DEFAULT 0,
    archived INTEGER NOT NULL DEFAULT 0,
    scheduled_task INTEGER NOT NULL DEFAULT 0,
    draft TEXT NOT NULL DEFAULT '',
    pending_goal TEXT,
    run_state TEXT NOT NULL DEFAULT 'idle',
    error_detail TEXT,
    active_run_id TEXT,
    message_count INTEGER NOT NULL DEFAULT 0
  )''',
  '''CREATE TABLE agent_runs (
    id TEXT PRIMARY KEY,
    conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    user_message_id TEXT,
    sender_id TEXT NOT NULL DEFAULT 'agent:aurai' REFERENCES message_senders(id),
    configuration_json TEXT,
    provider TEXT,
    model TEXT,
    status TEXT NOT NULL,
    started_at INTEGER,
    finished_at INTEGER,
    elapsed_ms INTEGER,
    is_task INTEGER NOT NULL DEFAULT 0,
    final_message_id TEXT,
    error_detail TEXT
  )''',
  '''CREATE TABLE model_turns (
    id TEXT PRIMARY KEY,
    conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    run_id TEXT NOT NULL REFERENCES agent_runs(id) ON DELETE CASCADE,
    ordinal INTEGER NOT NULL,
    response_id TEXT,
    response_json TEXT,
    status TEXT NOT NULL,
    started_at INTEGER NOT NULL,
    finished_at INTEGER,
    UNIQUE(run_id, ordinal)
  )''',
  '''CREATE TABLE messages (
    id TEXT PRIMARY KEY,
    conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    run_id TEXT REFERENCES agent_runs(id) ON DELETE CASCADE,
    model_turn_id TEXT REFERENCES model_turns(id) ON DELETE CASCADE,
    sender_id TEXT NOT NULL REFERENCES message_senders(id),
    quote_json TEXT,
    interactive_json TEXT,
    role TEXT NOT NULL,
    kind TEXT NOT NULL,
    text TEXT NOT NULL,
    created_at INTEGER NOT NULL
  )''',
  '''CREATE TABLE attachments (
    id TEXT PRIMARY KEY,
    conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    message_id TEXT REFERENCES messages(id) ON DELETE CASCADE,
    file_name TEXT NOT NULL,
    mime_type TEXT NOT NULL,
    kind TEXT NOT NULL DEFAULT 'image',
    display_name TEXT,
    byte_size INTEGER,
    position INTEGER NOT NULL
  )''',
  '''CREATE TABLE tool_calls (
    id TEXT PRIMARY KEY,
    conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    run_id TEXT NOT NULL REFERENCES agent_runs(id) ON DELETE CASCADE,
    model_turn_id TEXT NOT NULL REFERENCES model_turns(id) ON DELETE CASCADE,
    provider_call_id TEXT NOT NULL,
    name TEXT NOT NULL,
    title TEXT NOT NULL,
    arguments_json TEXT NOT NULL,
    status TEXT NOT NULL,
    result_status TEXT,
    result_json TEXT,
    started_at INTEGER NOT NULL,
    finished_at INTEGER,
    UNIQUE(run_id, provider_call_id)
  )''',
  '''CREATE TABLE tool_approvals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tool_call_id TEXT NOT NULL REFERENCES tool_calls(id) ON DELETE CASCADE,
    safety TEXT NOT NULL,
    scope_json TEXT NOT NULL,
    decision TEXT NOT NULL,
    requested_at INTEGER NOT NULL,
    resolved_at INTEGER
  )''',
  '''CREATE TABLE run_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    run_id TEXT NOT NULL REFERENCES agent_runs(id) ON DELETE CASCADE,
    kind TEXT NOT NULL,
    message_id TEXT UNIQUE REFERENCES messages(id) ON DELETE CASCADE,
    tool_call_id TEXT UNIQUE REFERENCES tool_calls(id) ON DELETE CASCADE,
    legacy_text TEXT,
    legacy_status TEXT
  )''',
  'CREATE INDEX conversation_archive_order ON conversations(archived, pinned DESC, updated_at DESC, id DESC)',
  'CREATE INDEX conversation_order ON conversations(pinned DESC, updated_at DESC, id DESC)',
  'CREATE INDEX message_history ON messages(conversation_id, created_at DESC, id DESC)',
  'CREATE INDEX message_run ON messages(run_id)',
  'CREATE INDEX attachment_conversation ON attachments(conversation_id, message_id)',
  'CREATE INDEX run_conversation ON agent_runs(conversation_id, started_at DESC)',
  'CREATE INDEX run_final_message ON agent_runs(final_message_id)',
  'CREATE INDEX turn_run ON model_turns(run_id, ordinal)',
  'CREATE INDEX tool_run ON tool_calls(run_id, started_at)',
  'CREATE INDEX approval_tool ON tool_approvals(tool_call_id)',
  'CREATE INDEX event_run ON run_events(run_id, id)',
];
