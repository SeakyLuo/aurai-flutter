import 'dart:io';
import 'package:flutter/services.dart';

import 'miniapp_library_store.dart';
import 'miniapp_send_action.dart';

/// Read capabilities from the same code version that will be sent. Database
/// lookups are batched for each bounded library page, never per application.
extension MiniappMessageCatalog on MiniappLibraryStore {
  Future<Set<String>> messageCapable(List<MiniappEntry> entries) async {
    final local = entries
        .where((e) => !e.bundled && e.kind != MiniappKind.published)
        .toList();
    final published = entries
        .where((e) => !e.bundled && e.kind == MiniappKind.published)
        .toList();
    Future<List<Map<String, Object?>>> paths(
      String table,
      String key,
      List<String> ids, {
      bool local = false,
    }) => ids.isEmpty
        ? Future.value([])
        : database.query(
            table,
            columns: [key, 'source_path', if (local) 'legacy_html'],
            where: '$key IN (${List.filled(ids.length, '?').join(',')})',
            whereArgs: ids,
          );
    final rows = await Future.wait([
      paths(
        'html_apps',
        'id',
        local.map((e) => e.runtimeId).toList(),
        local: true,
      ),
      paths(
        'miniapp_publications',
        'app_id',
        published.map((e) => e.id).toList(),
      ),
    ]);
    final localSources = {for (final row in rows[0]) row['id']: row};
    final releasePaths = {
      for (final row in rows[1]) row['app_id']: row['source_path'] as String,
    };
    final supported = await Future.wait(
      entries.map((entry) async {
        final String code;
        if (entry.bundled) {
          code = await rootBundle.loadString(entry.asset!);
        } else if (entry.kind == MiniappKind.published) {
          code = await File(releasePaths[entry.id]!).readAsString();
        } else {
          final source = localSources[entry.runtimeId]!;
          code = source['legacy_html'] != null
              ? source['legacy_html'] as String
              : await File(source['source_path'] as String).readAsString();
        }
        return supportsMiniappMessage(code)
            ? '${entry.kind.name}:${entry.id}'
            : null;
      }),
    );
    return supported.whereType<String>().toSet();
  }
}
