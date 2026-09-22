import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'miniapp_library_store.dart';
import 'miniapp_metadata_store.dart';
import '../storage/favorites.dart';

class MiniappFavorite {
  const MiniappFavorite(this.entry, this.starredAt);
  final MiniappEntry entry;
  final int starredAt;
}

class MiniappFavorites {
  MiniappFavorites(this.database);
  final Database database;

  String key(MiniappEntry entry) => entry.publicationId;

  Future<bool> contains(MiniappEntry entry) =>
      Favorites(database).contains('miniapp', key(entry));

  Future<void> add(MiniappEntry entry, {int? starredAt}) async {
    await Favorites(database).add(
      'miniapp',
      key(entry),
      starredAt: starredAt,
      metadata: jsonEncode({
        'id': entry.id,
        'title': entry.title,
        'publisher': entry.publisher,
        'description': entry.description,
        'iconPath': entry.iconPath,
        'iconAsset': entry.iconAsset,
        'kind': entry.kind.name,
        'asset': entry.asset,
        'bundleVersion': entry.bundleVersion,
        'sourceId': entry.sourceId,
      }),
    );
  }

  Future<int?> removeForUndo(MiniappEntry entry) =>
      database.transaction((txn) async {
        final rows = await txn.query(
          'favorites',
          columns: ['starred_at'],
          where: "owner_id = ? AND object_type = 'miniapp' AND object_id = ?",
          whereArgs: ['user:local', key(entry)],
        );
        if (rows.isEmpty) return null;
        await Favorites(txn).remove('miniapp', key(entry));
        return rows.single['starred_at'] as int;
      });

  Future<void> remove(MiniappEntry entry) =>
      Favorites(database).remove('miniapp', key(entry));

  Future<List<MiniappFavorite>> page({required int offset}) async {
    final rows = await Favorites(database).page('miniapp', offset: offset);
    final favorites = rows.map((row) {
      final data =
          jsonDecode(row['metadata_json'] as String) as Map<String, dynamic>;
      return MiniappFavorite(
        MiniappEntry(
          id: data['id'] as String,
          title: data['title'] as String,
          publisher: data['publisher'] as String,
          description: data['description'] as String,
          iconPath: data['iconPath'] as String?,
          iconAsset: data['iconAsset'] as String?,
          kind: MiniappKind.values.byName(data['kind'] as String),
          asset: data['asset'] as String?,
          bundleVersion: data['bundleVersion'] as String?,
          sourceId: data['sourceId'] as String?,
        ),
        row['starred_at'] as int,
      );
    }).toList();
    final entries = await MiniappMetadataStore(
      database,
    ).apply(favorites.map((favorite) => favorite.entry).toList());
    final bundled = await MiniappLibraryStore(database).bundled();
    final builtins = {for (final entry in bundled) entry.publicationId: entry};
    return [
      for (var i = 0; i < favorites.length; i++)
        MiniappFavorite(
          builtins[entries[i].publicationId] ?? entries[i],
          favorites[i].starredAt,
        ),
    ];
  }
}
