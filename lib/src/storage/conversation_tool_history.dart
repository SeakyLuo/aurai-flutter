import 'package:sqflite/sqflite.dart';

Future<List<String>> recentConversationTools(
  Database database,
  String conversationId,
) async {
  final runs = await database.query(
    'agent_runs',
    columns: ['id'],
    where: 'parent_run_id IS NULL AND conversation_id = ?',
    whereArgs: [conversationId],
    orderBy: 'started_at DESC',
    limit: 20,
  );
  if (runs.isEmpty) return [];
  final rows = await database.query(
    'tool_calls',
    columns: ['name'],
    where:
        "name NOT IN ('searchTools', 'loadTools') AND run_id IN (${List.filled(runs.length, '?').join(',')})",
    whereArgs: runs.map((run) => run['id']).toList(),
    orderBy: 'started_at DESC, rowid DESC',
    limit: 40,
  );
  return rows.reversed.map((row) => row['name'] as String).toList();
}
