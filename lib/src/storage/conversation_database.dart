import 'private_task_state.dart';
import 'organized_task_schema.dart';
import 'subagent_runs.dart';
import 'group_mute_schema.dart';
import 'asset_library_schema.dart';
import 'group_notice_dismissals.dart';
import 'project_directory_schema.dart';
import 'group_member_details.dart';
import 'group_message_marks.dart';
import '../html_games/miniapp_release_notes.dart';
import '../html_games/miniapp_recent_store.dart';
import '../html_games/miniapp_metadata_store.dart';
import 'favorites.dart';
import 'group_announcement_store.dart';
import '../html_games/miniapp_publication_schema.dart';
import '../html_games/html_app_store.dart';
import '../html_games/miniapp_team_schema.dart';
import 'approval_center_store.dart';
import 'interactive_action_history.dart';
import 'message_callbacks.dart';
import 'contact_relationships.dart';
import 'contact_store.dart';
import '../html_games/html_game_schema.dart';
import 'ai_identity_schema.dart';
import 'group_participation.dart';
import '../skills/skill_schema.dart';
import '../skills/skill_library_schema.dart';
import 'message_sender_schema.dart';
import 'group_chat_schema.dart';
import 'package:sqflite/sqflite.dart';
import '../memory/memory_controller.dart';
import '../memory/memory_storage_schema.dart';
import 'message_quick_reply_schema.dart';
import 'tool_customization_schema.dart';
import 'resource_scope_schema.dart';

const personalChatSchema = [
  'ALTER TABLE conversations ADD COLUMN personal_chat INTEGER NOT NULL DEFAULT 0 '
      "CHECK(personal_chat = 0 OR (kind = 'direct' AND mode = 'normal' AND project_id IS NULL))",
  'CREATE UNIQUE INDEX personal_chat_owner ON conversations(default_sender_id) '
      'WHERE personal_chat = 1',
];

Future<Database> openConversationDatabase() async => openDatabase(
  '${await getDatabasesPath()}/aurai.sqlite',
  version: 98,
  onOpen: (db) async {
    await db.update('approval_requests', {
      'status': 'cancelled',
      'resolved_at': DateTime.now().microsecondsSinceEpoch,
    }, where: "kind = 'tool' AND status = 'pending'");
  },
  onConfigure: (db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    await db.rawQuery('PRAGMA journal_mode = WAL');
  },
  onUpgrade: (db, oldVersion, newVersion) async {
    // Version 98 is the supported baseline; never silently advance an older backup.
    if (oldVersion < 98) {
      throw StateError('数据库版本低于 98，已不再支持自动升级此旧备份');
    }
  },
  onCreate: (db, version) async {
    final batch = db.batch();
    for (final statement in [
      ..._schema,
      ...personalChatSchema,
      privateTaskStateSchema,
      ...subagentRunSchema,
      organizedTaskSchema,
      organizedTaskOrderIndex,
      ...assetLibrarySchema,
      projectRecordSchema,
      ...projectDirectorySchema,
      projectConversationUpdateTrigger,
      projectConversationInsertTrigger,
      ...favoritesSchema,
      ...interactiveActionSchema,
      messageCallbackSchema,
      messageCallbackIndex,
      htmlAppSchema,
      htmlAppIndex,
      ...miniappTeamSchema,
      ...approvalCenterSchema,
      miniappReleaseNotesSchema,
      miniappRecentIndex,
      ...miniappPublicationSchema,
      miniappMetadataSchema,
      ...htmlGameSchema,
      'CREATE INDEX html_games_app ON html_games(app_id)',
      ...groupChatTables,
      messageMarkdownColumn,
      groupMuteColumn,
      groupWideMuteColumn,
      groupMuteMessageTrigger,
      groupAnnouncementSchema,
      groupNoticeDismissalsSchema,
      ...groupMessageMarksSchema,
      groupMemberDetailsSchema,
      groupParticipationSchema,
      temporaryAiColumn,
      ...contactRelationshipSchema,
      contactSchema,
      ...skillSchema,
      ...memorySchema,
      ...messageQuickReplySchema,
      toolCustomizationSchema,
    ]) {
      batch.execute(statement);
    }
    await batch.commit(noResult: true);
    await migrateAiIdentities(db);
    await migrateMemoryStorage(db);
    await migrateSkillLibrary(db);
    await migrateAuraiAvatar(db);
    await migrateAuraiDescription(db);
    await seedToolCustomizations(db);
    await db.execute(resourceScopeSchema);
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
    draft_updated_at INTEGER NOT NULL DEFAULT 0,
    title TEXT NOT NULL,
    kind TEXT NOT NULL DEFAULT 'direct',
    mode TEXT NOT NULL DEFAULT 'normal',
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
    project_id TEXT REFERENCES development_projects(id) ON DELETE SET NULL,
    join_approval_required INTEGER NOT NULL DEFAULT 0 CHECK(join_approval_required IN (0, 1)),
    managers_only_rename INTEGER NOT NULL DEFAULT 0 CHECK(managers_only_rename IN (0, 1)),
    group_avatar TEXT,
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
    miniapp_share_json TEXT,
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
  'CREATE INDEX conversation_archive_order ON conversations(archived, pinned DESC, MAX(updated_at, draft_updated_at) DESC, id DESC)',
  'CREATE INDEX conversation_order ON conversations(pinned DESC, MAX(updated_at, draft_updated_at) DESC, id DESC)',
  'CREATE INDEX conversation_project_order ON conversations(project_id, pinned DESC, MAX(updated_at, draft_updated_at) DESC, id DESC)',
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

const developmentProjectSchema = '''CREATE TABLE development_projects (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  instructions TEXT NOT NULL DEFAULT '',
  icon TEXT NOT NULL DEFAULT 'file',
  icon_color TEXT NOT NULL DEFAULT 'ink',
  root_uri TEXT NOT NULL UNIQUE,
  location TEXT NOT NULL CHECK(location IN ('external','managed')),
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  archived INTEGER NOT NULL DEFAULT 0,
  pinned INTEGER NOT NULL DEFAULT 0 CHECK(pinned IN (0, 1)),
  memory_mode TEXT NOT NULL DEFAULT 'shared' CHECK(memory_mode IN ('shared', 'projectOnly')),
  default_sender_id TEXT NOT NULL DEFAULT 'agent:aurai',
  git_remote_url TEXT NOT NULL DEFAULT ''
)''';

const projectConversationUpdateTrigger =
    '''CREATE TRIGGER project_conversation_updated
AFTER UPDATE OF updated_at ON conversations
WHEN NEW.project_id IS NOT NULL
BEGIN
  UPDATE development_projects
  SET updated_at = MAX(updated_at, NEW.updated_at)
  WHERE id = NEW.project_id;
END''';

const projectConversationInsertTrigger =
    '''CREATE TRIGGER project_conversation_created
AFTER INSERT ON conversations
WHEN NEW.project_id IS NOT NULL
BEGIN
  UPDATE development_projects
  SET updated_at = MAX(updated_at, NEW.updated_at)
  WHERE id = NEW.project_id;
END''';

const messageMarkdownColumn =
    'ALTER TABLE messages ADD COLUMN markdown INTEGER NOT NULL DEFAULT 0';
