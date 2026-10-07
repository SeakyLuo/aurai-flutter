import 'package:sqflite/sqflite.dart';
import 'memory_search.dart';

Future<void> unifyProjectMemories(DatabaseExecutor db) async {
  await db.execute('DROP TRIGGER memory_run_start');
  await db.execute(
    _schema.firstWhere(
      (sql) => sql.startsWith('CREATE TRIGGER memory_run_start'),
    ),
  );
  await db.execute("UPDATE development_projects SET memory_mode = 'shared'");
  await db.execute("""UPDATE user_memories SET memory_scope = CASE
    WHEN memory_scope LIKE 'project-only:%' THEN 'project:' || substr(memory_scope, 14)
    ELSE 'project:' || (SELECT project_id FROM conversations WHERE id = source_conversation_id) END
    WHERE memory_scope LIKE 'project-only:%' OR source_conversation_id IN
      (SELECT id FROM conversations WHERE project_id IS NOT NULL)""");
  await db.execute("""UPDATE memory_jobs SET scope = CASE
    WHEN scope LIKE 'project-only:%' THEN 'project:' || substr(scope, 14)
    ELSE 'project:' || (SELECT project_id FROM conversations WHERE id = conversation_id) END
    WHERE scope LIKE 'project-only:%' OR conversation_id IN
      (SELECT id FROM conversations WHERE project_id IS NOT NULL)""");
}

Future<void> migrateMemoryStorage(DatabaseExecutor db) async {
  for (final statement in _schema) {
    await db.execute(statement);
  }
  // Backfill in bounded pages; no per-record reads or model calls during migration.
  String after = '';
  while (true) {
    final rows = await db.query(
      'user_memories',
      columns: ['id', 'text'],
      where: 'id > ?',
      whereArgs: [after],
      orderBy: 'id',
      limit: 200,
    );
    if (rows.isEmpty) break;
    final batch = db.batch();
    for (final row in rows) {
      batch.update(
        'user_memories',
        memorySearchColumns(row['text'] as String),
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
    await batch.commit(noResult: true);
    after = rows.last['id'] as String;
  }
  await db.execute('''INSERT INTO memory_sources
    (memory_id, source_key, conversation_id, message_id)
    SELECT id, 'message:' || source_message_id, source_conversation_id, source_message_id
    FROM user_memories WHERE source_message_id IS NOT NULL''');
}

const _schema = [
  "ALTER TABLE user_memories ADD COLUMN kind TEXT NOT NULL DEFAULT 'note'",
  "ALTER TABLE user_memories ADD COLUMN assertion TEXT NOT NULL DEFAULT 'reported'",
  "ALTER TABLE user_memories ADD COLUMN state TEXT NOT NULL DEFAULT 'active'",
  'ALTER TABLE user_memories ADD COLUMN superseded_by TEXT',
  'ALTER TABLE user_memories ADD COLUMN version INTEGER NOT NULL DEFAULT 1',
  'ALTER TABLE user_memories ADD COLUMN last_used_at INTEGER NOT NULL DEFAULT 0',
  "ALTER TABLE user_memories ADD COLUMN keywords_json TEXT NOT NULL DEFAULT '[]'",
  "ALTER TABLE user_memories ADD COLUMN entities_json TEXT NOT NULL DEFAULT '[]'",
  "ALTER TABLE user_memories ADD COLUMN terms_json TEXT NOT NULL DEFAULT '{}'",
  "ALTER TABLE user_memories ADD COLUMN fingerprint TEXT NOT NULL DEFAULT ''",
  'CREATE INDEX memory_recent ON user_memories(owner_id, state, MAX(updated_at, last_used_at) DESC)',
  'CREATE INDEX memory_fingerprint ON user_memories(owner_id, memory_scope, fingerprint)',
  '''CREATE TABLE memory_terms (owner_id TEXT NOT NULL, term TEXT NOT NULL,
    memory_id TEXT NOT NULL REFERENCES user_memories(id) ON DELETE CASCADE,
    weight INTEGER NOT NULL, PRIMARY KEY(owner_id, term, memory_id)) WITHOUT ROWID''',
  'CREATE INDEX memory_terms_record ON memory_terms(memory_id)',
  '''CREATE TRIGGER memory_index_insert AFTER INSERT ON user_memories BEGIN
    INSERT INTO memory_terms SELECT NEW.owner_id, key, NEW.id, value FROM json_each(NEW.terms_json);
    END''',
  '''CREATE TRIGGER memory_index_update AFTER UPDATE OF terms_json ON user_memories BEGIN
    DELETE FROM memory_terms WHERE memory_id = NEW.id;
    INSERT INTO memory_terms SELECT NEW.owner_id, key, NEW.id, value FROM json_each(NEW.terms_json);
    END''',
  '''CREATE TABLE memory_sources (
    memory_id TEXT NOT NULL REFERENCES user_memories(id) ON DELETE CASCADE,
    source_key TEXT NOT NULL, conversation_id TEXT, run_id TEXT, message_id TEXT,
    tool_call_id TEXT, event_id INTEGER,
    PRIMARY KEY(memory_id, source_key)) WITHOUT ROWID''',
  '''CREATE TABLE memory_revisions (memory_id TEXT NOT NULL REFERENCES user_memories(id) ON DELETE CASCADE,
    version INTEGER NOT NULL, text TEXT NOT NULL, changed_at INTEGER NOT NULL,
    PRIMARY KEY(memory_id, version)) WITHOUT ROWID''',
  '''CREATE TABLE memory_tombstones (owner_id TEXT NOT NULL, source_key TEXT NOT NULL,
    PRIMARY KEY(owner_id, source_key)) WITHOUT ROWID''',
  '''CREATE TRIGGER memory_delete_guard BEFORE DELETE ON user_memories BEGIN
    INSERT OR IGNORE INTO memory_tombstones SELECT OLD.owner_id, source_key
      FROM memory_sources WHERE memory_id = OLD.id;
    INSERT OR IGNORE INTO memory_tombstones SELECT OLD.owner_id, 'run:' || run_id
      FROM memory_sources WHERE memory_id = OLD.id AND run_id IS NOT NULL;
    INSERT OR IGNORE INTO memory_tombstones SELECT OLD.owner_id, 'run:' || run_id
      FROM memory_evidence WHERE id IN (SELECT event_id FROM memory_sources WHERE memory_id = OLD.id);
    END''',
  '''CREATE TRIGGER memory_version AFTER UPDATE OF text ON user_memories
    WHEN NEW.text != OLD.text BEGIN
      INSERT INTO memory_revisions VALUES(OLD.id, OLD.version, OLD.text, NEW.updated_at);
      UPDATE user_memories SET version = OLD.version + 1 WHERE id = NEW.id;
    END''',
  '''CREATE TRIGGER memory_manual_guard AFTER UPDATE OF text ON user_memories
    WHEN NEW.manual = 1 BEGIN
      INSERT OR IGNORE INTO memory_tombstones SELECT NEW.owner_id, source_key
        FROM memory_sources WHERE memory_id = NEW.id;
      INSERT OR IGNORE INTO memory_tombstones SELECT NEW.owner_id, 'run:' || run_id
        FROM memory_sources WHERE memory_id = NEW.id AND run_id IS NOT NULL;
      INSERT OR IGNORE INTO memory_tombstones SELECT NEW.owner_id, 'run:' || run_id
        FROM memory_evidence WHERE id IN (SELECT event_id FROM memory_sources WHERE memory_id = NEW.id);
    END''',
  '''CREATE TABLE memory_message_origins (message_id TEXT PRIMARY KEY,
    author_id TEXT NOT NULL, source_message_id TEXT)''',
  '''CREATE TABLE memory_jobs (run_id TEXT PRIMARY KEY REFERENCES agent_runs(id) ON DELETE CASCADE,
    owner_id TEXT NOT NULL, scope TEXT NOT NULL, conversation_id TEXT NOT NULL,
    state TEXT NOT NULL DEFAULT 'waiting', cursor INTEGER NOT NULL DEFAULT 0, conflicts INTEGER NOT NULL DEFAULT 0,
    due_at INTEGER NOT NULL, error TEXT)''',
  'CREATE INDEX memory_jobs_due ON memory_jobs(state, due_at)',
  '''CREATE TABLE memory_evidence (id INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id TEXT NOT NULL REFERENCES memory_jobs(run_id) ON DELETE CASCADE,
    kind TEXT NOT NULL, source_id TEXT NOT NULL)''',
  'CREATE INDEX memory_evidence_run ON memory_evidence(run_id, id)',
  'CREATE INDEX memory_evidence_source ON memory_evidence(kind, source_id, id DESC)',
  'CREATE INDEX memory_evidence_run_source ON memory_evidence(run_id, kind, source_id, id DESC)',
  '''CREATE TRIGGER memory_run_start AFTER INSERT ON agent_runs
    WHEN NEW.parent_run_id IS NULL AND EXISTS (SELECT 1 FROM conversations WHERE id = NEW.conversation_id AND mode = 'normal')
    BEGIN
      INSERT INTO memory_jobs(run_id, owner_id, scope, conversation_id, due_at)
      SELECT NEW.id, NEW.sender_id,
        CASE WHEN c.project_id IS NOT NULL
          THEN 'project:' || c.project_id
          WHEN c.kind = 'group' THEN c.id ELSE '' END,
        c.id, CAST(strftime('%s','now') AS INTEGER) * 1000 + 60000
        FROM conversations c WHERE c.id = NEW.conversation_id;
      INSERT INTO memory_evidence(run_id, kind, source_id)
        SELECT NEW.id, 'message', NEW.user_message_id WHERE NEW.user_message_id IS NOT NULL;
    END''',
  '''CREATE TRIGGER memory_live_input AFTER INSERT ON messages
    WHEN NEW.role = 'user' AND NEW.run_id IS NULL BEGIN
      INSERT INTO memory_evidence(run_id, kind, source_id)
        SELECT active_run_id, 'message', NEW.id FROM conversations
        WHERE id = NEW.conversation_id AND kind = 'direct'
          AND active_run_id IN (SELECT run_id FROM memory_jobs)
          AND active_run_id IN (SELECT id FROM agent_runs WHERE status = 'running');
    END''',
  '''CREATE TRIGGER memory_message_insert AFTER INSERT ON messages
    WHEN NEW.kind != 'reasoning' AND NEW.model_turn_id IS NULL AND EXISTS(SELECT 1 FROM memory_jobs WHERE run_id = (SELECT COALESCE(parent_run_id, id) FROM agent_runs WHERE id = NEW.run_id))
    BEGIN INSERT INTO memory_evidence(run_id, kind, source_id) VALUES((SELECT COALESCE(parent_run_id, id) FROM agent_runs WHERE id = NEW.run_id), 'message', NEW.id); END''',
  '''CREATE TRIGGER memory_message_update AFTER UPDATE OF text ON messages
    WHEN NEW.text != OLD.text AND NEW.kind != 'reasoning'
      AND (NEW.model_turn_id IS NULL OR EXISTS(SELECT 1 FROM model_turns WHERE id = NEW.model_turn_id AND status != 'running'))
      AND EXISTS(SELECT 1 FROM memory_jobs WHERE run_id = (SELECT COALESCE(parent_run_id, id) FROM agent_runs WHERE id = NEW.run_id))
    BEGIN INSERT INTO memory_evidence(run_id, kind, source_id) VALUES((SELECT COALESCE(parent_run_id, id) FROM agent_runs WHERE id = NEW.run_id), 'message', NEW.id); END''',
  '''CREATE TRIGGER memory_turn_checkpoint AFTER UPDATE OF finished_at ON model_turns
    WHEN NEW.finished_at IS NOT NULL AND NEW.finished_at IS NOT OLD.finished_at
      AND EXISTS(SELECT 1 FROM memory_jobs WHERE run_id = (SELECT COALESCE(parent_run_id, id) FROM agent_runs WHERE id = NEW.run_id))
    BEGIN INSERT INTO memory_evidence(run_id, kind, source_id)
      SELECT (SELECT COALESCE(parent_run_id, id) FROM agent_runs WHERE id = NEW.run_id), 'message', id FROM messages WHERE model_turn_id = NEW.id AND kind != 'reasoning'; END''',
  '''CREATE TRIGGER memory_tool_finish AFTER UPDATE OF finished_at ON tool_calls
    WHEN NEW.finished_at IS NOT NULL AND NEW.finished_at IS NOT OLD.finished_at
      AND EXISTS(SELECT 1 FROM memory_jobs WHERE run_id = (SELECT COALESCE(parent_run_id, id) FROM agent_runs WHERE id = NEW.run_id))
    BEGIN INSERT INTO memory_evidence(run_id, kind, source_id) VALUES((SELECT COALESCE(parent_run_id, id) FROM agent_runs WHERE id = NEW.run_id), 'tool', NEW.id); END''',
  '''CREATE TRIGGER memory_run_finish AFTER UPDATE OF status ON agent_runs
    WHEN NEW.status != 'running' AND NEW.status != OLD.status
      AND EXISTS(SELECT 1 FROM memory_jobs WHERE run_id = COALESCE(NEW.parent_run_id, NEW.id))
    BEGIN
      INSERT INTO memory_evidence(run_id, kind, source_id)
        SELECT COALESCE(NEW.parent_run_id, NEW.id), 'message', id FROM messages WHERE run_id = NEW.id AND kind != 'reasoning'
          AND NOT EXISTS(SELECT 1 FROM memory_evidence WHERE run_id = COALESCE(NEW.parent_run_id, NEW.id) AND kind = 'message' AND source_id = messages.id);
      INSERT INTO memory_evidence(run_id, kind, source_id) VALUES(COALESCE(NEW.parent_run_id, NEW.id), 'run', NEW.id);
      UPDATE memory_jobs SET state = 'pending', due_at = 0
        WHERE run_id = COALESCE(NEW.parent_run_id, NEW.id) AND state != 'working'
          AND run_id IN (SELECT id FROM agent_runs WHERE status != 'running');
    END''',
];
