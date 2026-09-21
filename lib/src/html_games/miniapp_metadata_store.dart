import 'package:sqflite/sqflite.dart';

import 'miniapp_entry.dart';

const miniappMetadataSchema = '''CREATE TABLE miniapp_metadata (
  app_id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  icon_path TEXT,
  revision INTEGER NOT NULL
)''';

/// A previous development build may have created this table before advancing
/// user_version. Preserve its data when the versioned upgrade is retried.
Future<void> migrateMiniappMetadata(DatabaseExecutor database) async {
  final columns = await database.rawQuery(
    'PRAGMA table_info(miniapp_metadata)',
  );
  if (columns.isEmpty) {
    await database.execute(miniappMetadataSchema);
  } else if (!columns.any((column) => column['name'] == 'icon_path')) {
    await database.execute(
      'ALTER TABLE miniapp_metadata ADD COLUMN icon_path TEXT',
    );
  }
}

/// Display metadata is separate from application code, releases and saved data.
class MiniappMetadataStore {
  MiniappMetadataStore(this.database);
  final Database database;

  Future<List<MiniappEntry>> apply(List<MiniappEntry> entries) async {
    if (entries.isEmpty) return entries;
    final ids = entries.map((e) => e.publicationId).toSet().toList();
    final rows = await database.query(
      'miniapp_metadata',
      where: 'app_id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
    final metadata = {for (final row in rows) row['app_id']: row};
    return entries.map((entry) {
      final row = metadata[entry.publicationId];
      return row == null
          ? entry
          : entry.withMetadata(
              row['title'] as String,
              row['description'] as String,
              row['revision'] as int,
              iconPath: row['icon_path'] as String?,
              replaceIcon: true,
            );
    }).toList();
  }

  Future<void> save(
    MiniappEntry entry,
    String title,
    String description, {
    required String? iconPath,
  }) async {
    if (!entry.canEditMetadata) throw StateError('只能编辑自己小程序的资料');
    await database.transaction(
      (txn) => write(
        txn,
        entry,
        title,
        description,
        updateIcon: true,
        iconPath: iconPath,
      ),
    );
  }

  static Future<void> write(
    DatabaseExecutor txn,
    MiniappEntry entry,
    String title,
    String description, {
    bool updateIcon = false,
    String? iconPath,
  }) async {
    title = title.trim();
    description = description.trim();
    if (title.isEmpty ||
        title.length > 100 ||
        description.isEmpty ||
        description.length > 500) {
      throw ArgumentError('请填写名称和简介，名称最多 100 字、简介最多 500 字');
    }
    final rows = await txn.query(
      'miniapp_metadata',
      columns: ['revision'],
      where: 'app_id = ?',
      whereArgs: [entry.publicationId],
    );
    final revision = rows.isEmpty ? 0 : rows.single['revision'] as int;
    if (revision != entry.metadataRevision) throw StateError('资料已被修改，请重新打开编辑页');
    final values = <String, Object?>{
      'title': title,
      'description': description,
      'revision': revision + 1,
      if (updateIcon) 'icon_path': iconPath,
    };
    if (rows.isEmpty) {
      await txn.insert('miniapp_metadata', {
        ...values,
        'app_id': entry.publicationId,
      });
    } else {
      await txn.update(
        'miniapp_metadata',
        values,
        where: 'app_id = ?',
        whereArgs: [entry.publicationId],
      );
    }
  }
}
