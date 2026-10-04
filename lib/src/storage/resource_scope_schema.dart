import 'package:sqflite/sqflite.dart';

const resourceScopeSchema = '''CREATE TABLE resource_scopes (
  resource_type TEXT NOT NULL,
  resource_id TEXT NOT NULL,
  target_type TEXT NOT NULL,
  target_id TEXT NOT NULL,
  PRIMARY KEY (resource_type, resource_id, target_type, target_id)
)''';

Future<void> migrateResourceScopes(DatabaseExecutor db) async {
  await db.execute(resourceScopeSchema);
  // Only the existing Werewolf skill is migrated; other skills keep their scope.
  final rows = await Future.wait([
    db.query(
      'skills',
      columns: ['id'],
      where: 'name IN (?, ?)',
      whereArgs: ['狼人杀主持', 'werewolf-host'],
    ),
    db.query(
      'conversations',
      columns: ['id'],
      where: 'kind = ? AND title = ?',
      whereArgs: ['group', '狼人杀'],
    ),
  ]);
  final batch = db.batch();
  for (final skill in rows[0]) {
    for (final group in rows[1]) {
      batch.insert('resource_scopes', {
        'resource_type': 'skill',
        'resource_id': skill['id'],
        'target_type': 'group',
        'target_id': group['id'],
      });
    }
  }
  await batch.commit(noResult: true);
}
