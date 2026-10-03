import 'miniapp_library_store.dart';
import 'miniapp_message_catalog.dart';
import 'miniapp_favorites.dart';

/// Uses the same library entries and message declaration as the composer.
class MiniappAgentCatalog {
  MiniappAgentCatalog(this.library);
  final MiniappLibraryStore library;

  Future<Map<String, Object?>> list(Map<String, Object?> args) async {
    final source = args['source'] as String? ?? 'all';
    final offset = args['offset'] as int? ?? 0;
    final query = (args['query'] as String).toLowerCase();
    final bundled = await library.bundled();
    final entries = <MiniappEntry>[];
    var more = false;
    if (source == 'all' ||
        source == 'builtin' ||
        source == 'library' ||
        source == 'installed') {
      final matches = bundled
          .where(
            (e) =>
                e.title.toLowerCase().contains(query) &&
                (source != 'installed' || e.installedId != null),
          )
          .toList();
      entries.addAll(matches.skip(offset).take(50));
      more = matches.length > offset + 50;
    }
    final pages = await Future.wait([
      if (source == 'all' || source == 'library')
        library.page(
          bundledIds: bundled.map((e) => e.id).toList(),
          query: query,
          offset: offset,
        ),
      if (source == 'all' || source == 'mine' || source == 'installed')
        library.page(
          bundledIds: bundled.map((e) => e.id).toList(),
          query: query,
          offset: offset,
          mine: true,
          installed: source == 'installed'
              ? true
              : source == 'mine'
              ? false
              : null,
        ),
    ]);
    for (final page in pages) {
      entries.addAll(page.entries);
      more = more || page.more;
    }
    if (source == 'favorites') {
      final favorites = await MiniappFavorites(
        library.database,
      ).page(offset: offset);
      entries.addAll(
        favorites
            .map((e) => e.entry)
            .where((e) => e.title.toLowerCase().contains(query)),
      );
      more = favorites.length == 50;
    }
    final unique = {
      for (final entry in entries) '${entry.kind.name}:${entry.id}': entry,
    };
    final capable = await library.messageCapable(unique.values.toList());
    return {
      'apps': [
        for (final item in unique.entries)
          if (args['sendMode'] != 'message' || capable.contains(item.key))
            {
              'appId': item.value.id,
              'entryKind': item.value.kind.name,
              'title': item.value.title,
              'description': item.value.description,
              'bundled': item.value.bundled,
              'sendModes': ['share', if (capable.contains(item.key)) 'message'],
            },
      ],
      'hasMore': more,
      if (more) 'nextOffset': offset + 50,
    };
  }

  Future<MiniappEntry> resolve(String id, String kind) async {
    final bundled = await library.bundled();
    final builtin = bundled.where((e) => e.id == id).firstOrNull;
    if (builtin != null) return builtin;
    return kind == 'published'
        ? library.entryForPublication(id)
        : library.entryForApp(id);
  }
}
