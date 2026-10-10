import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../domain/interactive_message.dart';

/// Version 101 changes the stored presentation once. Runtime reads only content;
/// there is no legacy-protocol fallback in the message model or renderer.
Future<void> migrateInteractiveContent(DatabaseExecutor db) async {
  final rows = await Future.wait([
    db.query(
      'messages',
      columns: ['id', 'interactive_json'],
      where: 'interactive_json IS NOT NULL',
    ),
    db.query(
      'interactive_actions',
      columns: ['sequence', 'before_json'],
      where: 'before_json IS NOT NULL',
    ),
  ]);
  final batch = db.batch();
  for (final row in rows[0]) {
    final source = (jsonDecode(row['interactive_json'] as String) as Map)
        .cast<String, Object?>();
    final converted = _definition(source);
    batch.update(
      'messages',
      {'interactive_json': jsonEncode(converted)},
      where: 'id = ?',
      whereArgs: [row['id']],
    );
  }
  for (final row in rows[1]) {
    final source = (jsonDecode(row['before_json'] as String) as Map)
        .cast<String, Object?>();
    batch.update(
      'interactive_actions',
      {'before_json': jsonEncode(_definition(source))},
      where: 'sequence = ?',
      whereArgs: [row['sequence']],
    );
  }
  await batch.commit(noResult: true);
}

Map<String, Object?> _definition(Map<String, Object?> source) => {
  ...InteractiveMessage.cardDefinition(source),
  if (source['participants'] case final Map participants)
    'participants': {
      for (final entry in participants.entries)
        entry.key: (entry.value as Map).containsKey('buttons')
            ? _participant(
                source,
                Map<String, Object?>.from(entry.value as Map),
              )
            : entry.value,
    },
};

Map<String, Object?> _participant(
  Map<String, Object?> source,
  Map<String, Object?> value,
) => {
  for (final entry in value.entries)
    if (![
      'title',
      'body',
      'buttons',
      'showStatistics',
      'buttonColumns',
    ].contains(entry.key))
      entry.key: entry.value,
  'content': InteractiveContent.card(
    title: value['title'] as String? ?? source['title'] as String,
    body: value['body'] as String? ?? source['body'] as String,
    buttons: (value['buttons'] as List)
        .map((b) => Map<String, Object?>.from(b as Map))
        .toList(),
    buttonColumns:
        value['buttonColumns'] as int? ?? source['buttonColumns'] as int? ?? 1,
    showStatistics:
        value['showStatistics'] as bool? ??
        source['showStatistics'] as bool? ??
        true,
  ),
};
