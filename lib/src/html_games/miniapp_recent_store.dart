import 'package:sqflite/sqflite.dart';

const miniappRecentIndex =
    'CREATE INDEX IF NOT EXISTS html_apps_recent ON html_apps(last_opened_at DESC, id)';

Future<void> migrateMiniappRecents(DatabaseExecutor db) async {
  final columns = await db.rawQuery('PRAGMA table_info(html_apps)');
  if (!columns.any((column) => column['name'] == 'last_opened_at')) {
    await db.execute('ALTER TABLE html_apps ADD COLUMN last_opened_at INTEGER');
  }
  await db.execute(miniappRecentIndex);
}

Future<void> recordMiniappOpen(DatabaseExecutor db, String id) async {
  await db.update(
    'html_apps',
    {'last_opened_at': DateTime.now().millisecondsSinceEpoch},
    where: 'id = ?',
    whereArgs: [id],
  );
}
