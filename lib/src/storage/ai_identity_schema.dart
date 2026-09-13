import 'package:sqflite/sqflite.dart';

Future<void> migrateAiIdentities(Database db) async {
  final batch = db.batch();
  batch.execute('ALTER TABLE ai_profiles ADD COLUMN preferences TEXT');
  batch.execute(
    "ALTER TABLE user_memories ADD COLUMN owner_id TEXT NOT NULL DEFAULT 'agent:aurai'",
  );
  batch.execute(
    "ALTER TABLE user_memories ADD COLUMN memory_scope TEXT NOT NULL DEFAULT ''",
  );
  batch.execute(
    'CREATE INDEX memory_owner_scope ON user_memories(owner_id, memory_scope, created_at)',
  );
  batch.execute(
    'ALTER TABLE skill_dependencies RENAME TO old_skill_dependencies',
  );
  batch.execute('ALTER TABLE skills RENAME TO old_skills');
  batch.execute(
    "CREATE TABLE skills (id TEXT PRIMARY KEY, owner_id TEXT NOT NULL DEFAULT 'agent:aurai', name TEXT NOT NULL, description TEXT NOT NULL, instructions TEXT NOT NULL, script TEXT NOT NULL, enabled INTEGER NOT NULL, icon TEXT NOT NULL DEFAULT 'skill', revision INTEGER NOT NULL, UNIQUE(owner_id, name))",
  );
  batch.execute(
    'INSERT INTO skills (id,name,description,instructions,script,enabled,icon,revision) SELECT id,name,description,instructions,script,enabled,icon,revision FROM old_skills',
  );
  batch.execute(
    'CREATE TABLE skill_dependencies (skill_id TEXT NOT NULL REFERENCES skills(id) ON DELETE CASCADE, dependency_id TEXT NOT NULL REFERENCES skills(id) ON DELETE RESTRICT, PRIMARY KEY(skill_id, dependency_id), CHECK(skill_id != dependency_id))',
  );
  batch.execute(
    'INSERT INTO skill_dependencies SELECT * FROM old_skill_dependencies',
  );
  batch.execute('DROP TABLE old_skill_dependencies');
  batch.execute('DROP TABLE old_skills');
  batch.execute(
    'CREATE INDEX skill_dependencies_target ON skill_dependencies(dependency_id)',
  );
  await batch.commit(noResult: true);
}
