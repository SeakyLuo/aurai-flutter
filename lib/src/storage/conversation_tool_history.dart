import 'dart:convert';

import 'package:sqflite/sqflite.dart';

Future<List<String>> recentConversationTools(
  Database database,
  String conversationId,
) async {
  final runs = await database.query(
    'agent_runs',
    columns: ['id'],
    where: 'conversation_id = ?',
    whereArgs: [conversationId],
    orderBy: 'started_at DESC',
    limit: 20,
  );
  if (runs.isEmpty) return [];
  final rows = await database.query(
    'tool_calls',
    columns: [
      'name',
      "CASE WHEN name = 'searchTools' AND result_status = 'success' THEN result_json END AS search_result",
    ],
    where: 'run_id IN (${List.filled(runs.length, '?').join(',')})',
    whereArgs: runs.map((run) => run['id']).toList(),
    orderBy: 'started_at DESC, rowid DESC',
    limit: 40,
  );
  final names = <String>[];
  for (final row in rows.reversed) {
    final searchResult = row['search_result'] as String?;
    if (searchResult != null) {
      final result = jsonDecode(searchResult) as Map<String, dynamic>;
      final matches = (result['tools'] as List).cast<Map<String, dynamic>>();
      names.addAll(matches.reversed.map((tool) => tool['name'] as String));
    } else {
      names.add(row['name'] as String);
    }
  }
  return names;
}
