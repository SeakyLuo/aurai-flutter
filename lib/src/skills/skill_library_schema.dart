import 'dart:convert';
import 'package:sqflite/sqflite.dart';

Future<void> migrateSkillLibrary(Database db) async {
  await db.execute(
    "ALTER TABLE skills ADD COLUMN visibility TEXT NOT NULL DEFAULT 'private'",
  );
  await db.execute('''CREATE TABLE skill_installations (
    skill_id TEXT NOT NULL REFERENCES skills(id) ON DELETE CASCADE,
    owner_id TEXT NOT NULL,
    enabled INTEGER NOT NULL,
    permission TEXT,
    approved_revision INTEGER NOT NULL,
    PRIMARY KEY(skill_id, owner_id)
  )''');
  await db.execute(
    'CREATE INDEX skill_installation_owner ON skill_installations(owner_id)',
  );
  await db.execute('''CREATE TABLE skill_visibility_members (
    skill_id TEXT NOT NULL REFERENCES skills(id) ON DELETE CASCADE,
    member_id TEXT NOT NULL,
    PRIMARY KEY(skill_id, member_id)
  )''');
  await db.execute(
    'CREATE INDEX skill_visibility_member ON skill_visibility_members(member_id)',
  );
  await db.execute(
    '''INSERT INTO skill_installations(skill_id,owner_id,enabled,approved_revision)
    SELECT id,owner_id,enabled,revision FROM skills''',
  );
  final permissions = await db.query(
    'app_state',
    where: 'key = ? OR key LIKE ?',
    whereArgs: ['skill_permissions', '%:skill_permissions'],
  );
  final batch = db.batch();
  for (final row in permissions) {
    final key = row['key'] as String;
    final owner = key == 'skill_permissions'
        ? 'agent:aurai'
        : key.substring(0, key.length - ':skill_permissions'.length);
    for (final entry in (jsonDecode(row['value'] as String) as Map).entries) {
      batch.update(
        'skill_installations',
        {'permission': entry.value},
        where: 'skill_id = ? AND owner_id = ?',
        whereArgs: [entry.key, owner],
      );
    }
  }
  await batch.commit(noResult: true);
}
