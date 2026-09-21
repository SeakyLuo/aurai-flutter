import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/agent_models.dart';
import '../domain/message_sender.dart';
import 'html_app_store.dart';
import 'html_game.dart';
import 'miniapp_entry.dart';
import 'miniapp_metadata_store.dart';
export 'miniapp_entry.dart';
part 'miniapp_publication_store.dart';

class MiniappLibraryStore {
  MiniappLibraryStore(this.database);
  final Database database;
  static const owner = 'user:local';

  Future<List<MiniappEntry>> bundled() async {
    final entries =
        jsonDecode(await rootBundle.loadString('assets/miniapps/catalog.json'))
            as List;
    final ids = entries.map((e) => e['id'] as String).toList();
    final installations = await _rows(
      'miniapp_installations',
      'source_id',
      ids,
    );
    final installed = {for (final row in installations) row['source_id']: row};
    final profiles = await _names(
      entries.map((e) => e['publisherId'] as String),
    );
    return MiniappMetadataStore(database).apply(
      entries
          .map(
            (e) => MiniappEntry(
              id: e['id'] as String,
              title: e['title'] as String,
              publisher: profiles[e['publisherId']]!.name,
              publisherProfile: profiles[e['publisherId']],
              description: e['description'] as String,
              asset: e['asset'] as String,
              bundleVersion: e['version'] as String,
              listed: true,
              revision: 1,
              installedId: installed[e['id']]?['app_id'] as String?,
              installedRevision: installed[e['id']]?['revision'] as String?,
            ),
          )
          .toList(),
    );
  }

  Future<List<Map<String, Object?>>> _rows(
    String table,
    String column,
    List<String> ids,
  ) => ids.isEmpty
      ? Future.value([])
      : database.query(
          table,
          where:
              '$column IN (${List.filled(ids.length, '?').join(',')})${table == 'miniapp_installations' ? ' AND owner_id = ?' : ''}',
          whereArgs: [...ids, if (table == 'miniapp_installations') owner],
        );

  Future<Map<String, MessageSender>> _names(Iterable<String> ids) async {
    final rows = await _rows('message_senders', 'id', ids.toSet().toList());
    return {
      for (final row in rows) row['id'] as String: MessageSender.fromRow(row),
    };
  }

  Future<({List<MiniappEntry> entries, bool more})> page({
    required List<String> bundledIds,
    MiniappEntry? after,
    String query = '',
    bool mine = false,
    bool? installed,
  }) async {
    final key = mine ? 'id' : 'app_id';
    final metadataKey = mine
        ? "COALESCE((SELECT source_id FROM miniapp_installations WHERE app_id = html_apps.id AND owner_id = 'user:local'), html_apps.id)"
        : 'miniapp_publications.app_id';
    final rows = await database.query(
      mine ? 'html_apps' : 'miniapp_publications',
      columns: mine ? ['id', 'title', 'creator_id', 'updated_at'] : null,
      where: [
        'instr(lower(COALESCE((SELECT title FROM miniapp_metadata WHERE app_id = $metadataKey), title)), lower(?)) > 0',
        if (!mine) 'listed = 1',
        if (mine && installed != null)
          "id ${installed ? 'IN' : 'NOT IN'} (SELECT app_id FROM miniapp_installations WHERE owner_id = 'user:local')",
        if (bundledIds.isNotEmpty)
          '$key NOT IN (${List.filled(bundledIds.length, '?').join(',')})',
        if (after != null) '(updated_at < ? OR (updated_at = ? AND $key > ?))',
      ].join(' AND '),
      whereArgs: [
        query,
        ...bundledIds,
        if (after != null) ...[after.updatedAt, after.updatedAt, after.id],
      ],
      orderBy: 'updated_at DESC, $key',
      limit: 51,
    );
    final slice = rows.take(50).toList();
    return (
      entries: await MiniappMetadataStore(
        database,
      ).apply(mine ? await _mine(slice) : await _published(slice)),
      more: rows.length > 50,
    );
  }

  Future<List<MiniappEntry>> _published(List<Map<String, Object?>> rows) async {
    final installations = await _rows(
      'miniapp_installations',
      'source_id',
      rows.map((r) => r['app_id'] as String).toList(),
    );
    final installed = {for (final r in installations) r['source_id']: r};
    final names = await _names(rows.map((r) => r['publisher_id'] as String));
    return rows
        .map(
          (r) => MiniappEntry(
            id: r['app_id'] as String,
            title: r['title'] as String,
            description: r['description'] as String,
            publisher: names[r['publisher_id']]?.name ?? '原发布人',
            publisherProfile: names[r['publisher_id']],
            revision: r['revision'] as int,
            listed: r['listed'] == 1,
            updatedAt: r['updated_at'] as int,
            installedId: installed[r['app_id']]?['app_id'] as String?,
            installedRevision: installed[r['app_id']]?['revision'] as String?,
          ),
        )
        .toList();
  }

  Future<List<MiniappEntry>> _mine(List<Map<String, Object?>> rows) async {
    final installations = await _rows(
      'miniapp_installations',
      'app_id',
      rows.map((r) => r['id'] as String).toList(),
    );
    final installed = {for (final r in installations) r['app_id']: r};
    final publications = await _rows(
      'miniapp_publications',
      'app_id',
      rows
          .map((r) => (installed[r['id']]?['source_id'] ?? r['id']) as String)
          .toList(),
    );
    final releases = {for (final r in publications) r['app_id']: r};
    final names = await _names([
      ...rows.map((r) => r['creator_id'] as String),
      ...publications.map((r) => r['publisher_id'] as String),
    ]);
    return rows.map((r) {
      final installation = installed[r['id']];
      final source = installation?['source_id'] as String?;
      final release = releases[source ?? r['id']];
      return MiniappEntry(
        id: r['id'] as String,
        title: r['title'] as String,
        publisher:
            names[installation == null
                    ? r['creator_id']
                    : release?['publisher_id']]
                ?.name ??
            '原发布人',
        publisherProfile:
            names[installation == null
                ? r['creator_id']
                : release?['publisher_id']],
        description: release?['description'] as String? ?? '',
        publishedTitle: release?['title'] as String?,
        kind: installation == null ? MiniappKind.draft : MiniappKind.installed,
        sourceId: source,
        installedId: installation?['app_id'] as String?,
        installedRevision: installation?['revision'] as String?,
        revision: release?['revision'] as int? ?? 0,
        listed: release?['listed'] == 1,
        updatedAt: r['updated_at'] as int,
      );
    }).toList();
  }

  Future<MiniappEntry> entryForApp(String appId) async {
    final builtins = await bundled();
    for (final entry in builtins) {
      if (entry.id == appId || entry.installedId == appId) return entry;
    }
    final rows = await database.query(
      'html_apps',
      where: 'id = ?',
      whereArgs: [appId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('小程序已不存在');
    return (await MiniappMetadataStore(
      database,
    ).apply(await _mine(rows))).single;
  }

  Future<MiniappEntry> refresh(MiniappEntry entry) async {
    if (entry.bundled)
      return (await bundled()).singleWhere((e) => e.id == entry.id);
    final release = entry.kind == MiniappKind.published;
    final rows = await database.query(
      release ? 'miniapp_publications' : 'html_apps',
      where: '${release ? 'app_id' : 'id'} = ?',
      whereArgs: [entry.id],
    );
    if (rows.isEmpty) throw StateError('小程序已不存在，请返回列表');
    return (await MiniappMetadataStore(
      database,
    ).apply(release ? await _published(rows) : await _mine(rows))).single;
  }

  Future<Map<String, Object?>?> launcher(String id) async {
    final rows = await database.query(
      'html_games',
      columns: ['message_id', 'conversation_id'],
      where:
          "app_id = ? AND message_id IN (SELECT id FROM messages WHERE kind = 'html_game')",
      whereArgs: [id],
      orderBy: 'rowid DESC',
      limit: 1,
    );
    return rows.firstOrNull;
  }

  Future<HtmlGame> loadIndependent(String id) async {
    final app = await HtmlAppStore.load(database, id);
    final metadata = await database.query(
      'miniapp_metadata',
      columns: ['title'],
      where:
          "app_id = COALESCE((SELECT source_id FROM miniapp_installations WHERE app_id = ? AND owner_id = 'user:local'), ?)",
      whereArgs: [id, id],
    );
    return HtmlGame(
      messageId: 'library:$id',
      appId: id,
      conversationId: '',
      creatorId: app['creator_id'] as String,
      title:
          (metadata.isEmpty ? app['title'] : metadata.single['title'])
              as String,
      html: await HtmlAppStore.code(app),
      state: (jsonDecode(app['state_json'] as String) as Map)
          .cast<String, Object?>(),
      version: app['version'] as int,
      stateful: app['stateful'] == 1,
      participants: const [],
      status: 'active',
      turnSenderId: null,
      width: null,
      height: 320,
      canRetry: false,
    );
  }
}
