const organizedTaskSchema = '''CREATE TABLE organized_tasks (
  task_id TEXT PRIMARY KEY REFERENCES conversations(id) ON DELETE CASCADE,
  conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  source_message_id TEXT REFERENCES messages(id) ON DELETE SET NULL
)''';

const organizedTaskOrderIndex =
    'CREATE INDEX organized_task_source ON organized_tasks(conversation_id, task_id)';
