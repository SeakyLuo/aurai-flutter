import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'miniapp_library_store.dart';

/// A reference to reusable code and interaction rules, without a running round.
class MiniappTemplate {
  const MiniappTemplate(this.appId, this.title, this.definition);
  final String appId, title;
  final Map<String, Object?> definition;

  static Future<MiniappTemplate> load(Database db, MiniappEntry entry) async {
    final library = MiniappLibraryStore(db);
    final appId = entry.bundled || entry.kind == MiniappKind.published
        ? await library.install(entry)
        : entry.runtimeId;
    final launchers = await db.rawQuery(
      '''SELECT g.display_width, g.display_height,
      g.display_mode, g.background_mode, m.interactive_json
      FROM html_games g INNER JOIN messages m ON m.id = g.message_id
      WHERE g.app_id IN (?, ?) ORDER BY g.updated_at DESC LIMIT 1''',
      [appId, entry.publicationId],
    );
    final definition = <String, Object?>{};
    if (launchers.isNotEmpty) {
      final launcher = launchers.single;
      definition.addAll({
        'width': launcher['display_width'],
        'height': launcher['display_height'],
        'displayMode': launcher['display_mode'],
        'backgroundMode': launcher['background_mode'],
      });
      if (launcher['interactive_json'] case final String raw) {
        final rules = jsonDecode(raw) as Map;
        definition['interaction'] = rules['interaction'];
        definition['buttons'] = rules['buttons'];
      }
    }
    return MiniappTemplate(appId, entry.title, definition);
  }
}
