import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import '../domain/library_asset.dart';

class AssetLibrary {
  const AssetLibrary(this.database, this.directory);
  final Database database;
  final String directory;
  static const pageSize = 40;

  Future<List<LibraryAsset>> page({
    required int offset,
    int limit = pageSize,
    String query = '',
    AssetSource? source,
    AssetType? type,
    AssetSort sort = AssetSort.newest,
    bool trash = false,
  }) async {
    final conditions = [
      'purged = 0',
      trash ? 'deleted_at IS NOT NULL' : 'deleted_at IS NULL',
      if (source != null) 'source = ?',
      if (query.isNotEmpty) 'instr(lower(name), ?) > 0',
    ];
    const image = "(kind = 'image' OR mime_type LIKE 'image/%')";
    const media = "(mime_type LIKE 'audio/%' OR mime_type LIKE 'video/%')";
    // File extensions cover Office files whose upload MIME is generic.
    final documents =
        '(${AssetType.documentExtensions.map((extension) => "lower(name) LIKE '%.$extension'").join(' OR ')})';
    switch (type) {
      case AssetType.image:
        conditions.add(image);
      case AssetType.document:
        conditions.add('NOT $image AND $documents');
      case AssetType.media:
        conditions.add('NOT $image AND $media');
      case AssetType.other:
        conditions.add('NOT $image AND NOT $media AND NOT $documents');
      case null:
        break;
    }
    final rows = await database.query(
      'assets',
      where: conditions.join(' AND '),
      whereArgs: [
        if (source != null) source.name,
        if (query.isNotEmpty) query.toLowerCase(),
      ],
      orderBy: sort.orderBy,
      limit: limit,
      offset: offset,
    );
    return rows.map((row) => LibraryAsset.fromRow(row, directory)).toList();
  }

  Future<void> rename(LibraryAsset asset, String name) async {
    await database.update(
      'assets',
      {'name': name},
      where: 'file_name = ? AND purged = 0',
      whereArgs: [asset.id],
    );
  }

  Future<void> moveToTrash(List<String> ids) =>
      _update(ids, {'deleted_at': DateTime.now().microsecondsSinceEpoch});
  Future<void> restore(List<String> ids) => _update(ids, {'deleted_at': null});
  Future<void> _update(List<String> ids, Map<String, Object?> values) async {
    await database.update(
      'assets',
      values,
      where: 'file_name IN (SELECT value FROM json_each(?)) AND purged = 0',
      whereArgs: [jsonEncode(ids)],
    );
  }

  Future<void> purge(List<String> ids) => _purge(ids);
  Future<void> clearTrash() => _purge(null);

  Future<void> _purge(List<String>? ids) async {
    await database.transaction((txn) async {
      final rows = await txn.query(
        'assets',
        columns: ['file_name'],
        where:
            '${ids == null ? '' : 'file_name IN (SELECT value FROM json_each(?)) AND '}deleted_at IS NOT NULL AND purged = 0',
        whereArgs: [if (ids != null) jsonEncode(ids)],
      );
      final names = rows.map((row) => row['file_name'] as String).toList();
      // Keep the filename tombstone so later message saves cannot resurrect it.
      await txn.update(
        'assets',
        {'purged': 1},
        where: 'file_name IN (SELECT value FROM json_each(?))',
        whereArgs: [jsonEncode(names)],
      );
      final paths = await unreferencedPaths(
        txn,
        names.map((name) => '$directory/$name'),
      );
      for (final path in paths) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    });
  }

  static Future<List<String>> unreferencedPaths(
    DatabaseExecutor db,
    Iterable<String> paths,
  ) async {
    final candidates = paths.toSet().toList();
    if (candidates.isEmpty) return [];
    final names = jsonEncode(
      candidates.map((path) => File(path).uri.pathSegments.last).toList(),
    );
    final rows = await db.rawQuery(
      '''SELECT file_name FROM attachments
      WHERE file_name IN (SELECT value FROM json_each(?))
      UNION SELECT file_name FROM assets
      WHERE purged = 0 AND file_name IN (SELECT value FROM json_each(?))''',
      [names, names],
    );
    final retained = rows.map((row) => row['file_name']).toSet();
    return candidates
        .where((path) => !retained.contains(File(path).uri.pathSegments.last))
        .toList();
  }
}
