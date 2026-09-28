import 'package:sqflite/sqflite.dart';

const projectRecordSchema = '''CREATE TABLE development_projects (
  id TEXT PRIMARY KEY, name TEXT NOT NULL, description TEXT NOT NULL DEFAULT '',
  instructions TEXT NOT NULL DEFAULT '', icon TEXT NOT NULL DEFAULT 'file',
  icon_color TEXT NOT NULL DEFAULT 'ink', created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL, archived INTEGER NOT NULL DEFAULT 0,
  pinned INTEGER NOT NULL DEFAULT 0 CHECK(pinned IN (0, 1)),
  memory_mode TEXT NOT NULL DEFAULT 'shared' CHECK(memory_mode IN ('shared', 'projectOnly')),
  default_sender_id TEXT NOT NULL DEFAULT 'agent:aurai'
)''';

const projectDirectorySchema = [
  '''CREATE TABLE workspace_directories (
    uri TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    repository_uri TEXT REFERENCES workspace_directories(uri) ON DELETE RESTRICT
  )''',
  '''CREATE TABLE project_directories (
    project_id TEXT NOT NULL REFERENCES development_projects(id) ON DELETE CASCADE,
    directory_uri TEXT NOT NULL REFERENCES workspace_directories(uri) ON DELETE CASCADE,
    PRIMARY KEY(project_id, directory_uri)
  )''',
  'CREATE INDEX directory_projects ON project_directories(directory_uri)',
];

Future<void> migrateProjectDirectories(Database db) async {
  await db.execute(
    'CREATE TEMP TABLE previous_projects AS SELECT * FROM development_projects',
  );
  await db.execute(
    'CREATE TEMP TABLE previous_project_chats AS SELECT id, project_id FROM conversations WHERE project_id IS NOT NULL',
  );
  await db.execute('DROP TABLE development_projects');
  await db.execute(projectRecordSchema);
  const columns =
      'id, name, description, instructions, icon, icon_color, created_at, updated_at, archived, pinned, memory_mode, default_sender_id';
  await db.execute(
    'INSERT INTO development_projects($columns) SELECT $columns FROM previous_projects',
  );
  await db.execute('''UPDATE conversations SET project_id =
    (SELECT project_id FROM previous_project_chats WHERE previous_project_chats.id = conversations.id)
    WHERE id IN (SELECT id FROM previous_project_chats)''');
  for (final statement in projectDirectorySchema) {
    await db.execute(statement);
  }
  await db.execute('''INSERT INTO workspace_directories(uri, name)
    SELECT root_uri, name FROM previous_projects''');
  await db.execute('''INSERT INTO project_directories(project_id, directory_uri)
    SELECT id, root_uri FROM previous_projects''');
  await db.execute(
    '''INSERT OR IGNORE INTO workspace_directories(uri, name, repository_uri)
    SELECT 'aurai://project/' || json_extract(value, '\$.id'), json_extract(value, '\$.name'),
      (SELECT root_uri FROM previous_projects WHERE id = json_extract(value, '\$.projectId'))
    FROM app_state WHERE key LIKE 'conversation_worktree:%'
      AND json_extract(value, '\$.id') IS NOT NULL AND COALESCE(json_extract(value, '\$.deleted'), 0) = 0''',
  );
  await db.execute(
    '''INSERT OR IGNORE INTO project_directories(project_id, directory_uri)
    SELECT json_extract(value, '\$.projectId'), 'aurai://project/' || json_extract(value, '\$.id')
    FROM app_state WHERE key LIKE 'conversation_worktree:%'
      AND json_extract(value, '\$.id') IS NOT NULL AND COALESCE(json_extract(value, '\$.deleted'), 0) = 0
      AND json_extract(value, '\$.projectId') IN (SELECT id FROM development_projects)''',
  );
  await db.delete('app_state', where: "key LIKE 'conversation_worktree:%'");
  await db.execute('DROP TABLE previous_project_chats');
  await db.execute('DROP TABLE previous_projects');
}
