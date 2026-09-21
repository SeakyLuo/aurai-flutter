import 'package:sqflite/sqflite.dart';

const favoritesSchema = [
  '''CREATE TABLE favorites (
    owner_id TEXT NOT NULL,
    object_type TEXT NOT NULL,
    object_id TEXT NOT NULL,
    metadata_json TEXT NOT NULL DEFAULT '{}',
    starred_at INTEGER NOT NULL,
    PRIMARY KEY (owner_id, object_type, object_id)
  )''',
  'CREATE INDEX favorites_time ON favorites(owner_id, object_type, starred_at DESC, object_id DESC)',
  '''CREATE TRIGGER favorites_message_insert BEFORE INSERT ON favorites
    WHEN NEW.object_type = 'message' AND NOT EXISTS (SELECT 1 FROM messages WHERE id = NEW.object_id)
    BEGIN
      SELECT RAISE(ABORT, '消息已不存在');
    END''',
  '''CREATE TRIGGER favorites_message_deleted AFTER DELETE ON messages
    BEGIN
      DELETE FROM favorites WHERE object_type = 'message' AND object_id = OLD.id;
    END''',
];

/// Development databases can already contain the new table while user_version
/// still points to an older build. Complete this migration without replacing
/// newer favorites or assuming the legacy table is still present.
Future<void> migrateFavorites(DatabaseExecutor database) async {
  for (final statement in favoritesSchema) {
    await database.execute(
      statement
          .replaceFirst('CREATE TABLE ', 'CREATE TABLE IF NOT EXISTS ')
          .replaceFirst('CREATE INDEX ', 'CREATE INDEX IF NOT EXISTS ')
          .replaceFirst('CREATE TRIGGER ', 'CREATE TRIGGER IF NOT EXISTS '),
    );
  }
  for (final table in ['starred_messages', 'starred_messages_legacy']) {
    final columns = await database.rawQuery('PRAGMA table_info($table)');
    if (columns.isEmpty) continue;
    final owner = columns.any((column) => column['name'] == 'owner_id')
        ? 'owner_id'
        : "'user:local'";
    await database.execute(
      "INSERT OR IGNORE INTO favorites(owner_id, object_type, object_id, starred_at) "
      "SELECT $owner, 'message', message_id, starred_at FROM $table "
      "WHERE message_id IN (SELECT id FROM messages)",
    );
    await database.execute('DROP TABLE $table');
  }
}

class Favorites {
  Favorites(this.database, {this.ownerId = 'user:local'});
  final DatabaseExecutor database;
  final String ownerId;

  Future<bool> contains(String type, String id) async => (await database.query(
    'favorites',
    columns: ['object_id'],
    where: 'owner_id = ? AND object_type = ? AND object_id = ?',
    whereArgs: [ownerId, type, id],
    limit: 1,
  )).isNotEmpty;

  Future<void> add(
    String type,
    String id, {
    String metadata = '{}',
    int? starredAt,
  }) async {
    await database.insert('favorites', {
      'owner_id': ownerId,
      'object_type': type,
      'object_id': id,
      'metadata_json': metadata,
      'starred_at': starredAt ?? DateTime.now().microsecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> remove(String type, String id) async {
    await database.delete(
      'favorites',
      where: 'owner_id = ? AND object_type = ? AND object_id = ?',
      whereArgs: [ownerId, type, id],
    );
  }

  Future<List<Map<String, Object?>>> page(String type, {required int offset}) =>
      database.query(
        'favorites',
        where: 'owner_id = ? AND object_type = ?',
        whereArgs: [ownerId, type],
        orderBy: 'starred_at DESC, object_id DESC',
        offset: offset,
        limit: 50,
      );
}
