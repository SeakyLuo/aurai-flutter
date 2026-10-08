import 'package:sqflite/sqflite.dart';

Future<void> migrateMemoryQueue(DatabaseExecutor db) async {
  for (final sql in memoryQueueSchema) {
    await db.execute(sql);
  }
}

const memoryQueueSchema = [
  'ALTER TABLE memory_jobs ADD COLUMN batch_json TEXT',
  'ALTER TABLE memory_jobs ADD COLUMN text_offset INTEGER NOT NULL DEFAULT 0',
  'ALTER TABLE memory_jobs ADD COLUMN retries INTEGER NOT NULL DEFAULT 0',
  "ALTER TABLE memory_jobs ADD COLUMN config_key TEXT NOT NULL DEFAULT ''",
  'ALTER TABLE memory_jobs ADD COLUMN text_fingerprint TEXT',
  'ALTER TABLE memory_jobs ADD COLUMN queued_at INTEGER NOT NULL DEFAULT 0',
  '''CREATE TABLE memory_attempts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id TEXT NOT NULL REFERENCES memory_jobs(run_id) ON DELETE CASCADE,
    started_at INTEGER NOT NULL, finished_at INTEGER, model TEXT NOT NULL,
    response_id TEXT, status TEXT NOT NULL, error TEXT,
    start_cursor INTEGER NOT NULL, end_cursor INTEGER NOT NULL,
    start_offset INTEGER NOT NULL, end_offset INTEGER NOT NULL)''',
  'CREATE INDEX memory_attempts_job ON memory_attempts(run_id, id)',
  '''CREATE TABLE memory_run_jobs (
    run_id TEXT PRIMARY KEY REFERENCES agent_runs(id) ON DELETE CASCADE,
    job_id TEXT NOT NULL REFERENCES memory_jobs(run_id) ON DELETE CASCADE)''',
  'CREATE INDEX memory_run_jobs_job ON memory_run_jobs(job_id)',
  'CREATE INDEX memory_jobs_source ON memory_jobs(owner_id, conversation_id, state)',
  'INSERT INTO memory_run_jobs SELECT run_id, run_id FROM memory_jobs',
  '''UPDATE memory_jobs SET queued_at = CAST(strftime('%s','now') AS INTEGER) * 1000''',
  // Preserve failures from the old single-error slot before any retry overwrites it.
  '''INSERT INTO memory_attempts(run_id, started_at, finished_at, model, status,
    error, start_cursor, end_cursor, start_offset, end_offset)
    SELECT run_id, queued_at, queued_at, '', 'failed', error, cursor, cursor, 0, 0
    FROM memory_jobs WHERE error IS NOT NULL''',
];
