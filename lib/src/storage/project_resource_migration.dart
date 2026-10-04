import 'package:sqflite/sqflite.dart';
import '../domain/resource_scope.dart';

Future<void> migrateWerewolfProjectResources(DatabaseExecutor db) async {
  final rows = await Future.wait([
    db.query(
      'development_projects',
      columns: ['id'],
      where: 'name = ?',
      whereArgs: ['狼人杀'],
    ),
    db.query(
      'skills',
      columns: ['id'],
      where: 'name IN (?, ?, ?)',
      whereArgs: ['狼人杀主持', '狼人杀玩家', 'werewolf-host'],
    ),
    db.query('tool_customizations', columns: ['name']),
  ]);
  if (rows[0].isEmpty) return;
  final project = rows[0].single['id'] as String;
  final scope = ResourceScope.project(project);
  final names = rows[2].map((row) => row['name']).toSet();
  final batch = db.batch();
  for (final name in ['finishCurrentAction', 'submitInteractiveChoice']) {
    if (!names.contains(name)) {
      batch.insert('tool_customizations', {
        'name': name,
        'icon': 'skill:conversation',
      });
    }
  }
  // Moving only these resources preserves unrelated scope bindings and skill content.
  final resources = [
    for (final skill in rows[1]) ('skill', skill['id'] as String),
    ('tool', 'finishCurrentAction'),
    ('tool', 'submitInteractiveChoice'),
  ];
  for (final (type, id) in resources) {
    batch.delete(
      'resource_scopes',
      where: 'resource_type = ? AND resource_id = ?',
      whereArgs: [type, id],
    );
    batch.insert('resource_scopes', {
      'resource_type': type,
      'resource_id': id,
      'target_type': scope.type,
      'target_id': scope.id,
    });
  }
  await batch.commit(noResult: true);
}
