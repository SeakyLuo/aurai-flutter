import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../domain/model_provider.dart';

/// Replay complete exchanges as one compaction unit. Legacy and interrupted
/// runs retain their visible transcript; never invent missing tool results.
Future<Map<String, List<Map<String, Object?>>>> loadProtocolHistory(
  Database database,
  String conversationId,
  List<Map<String, Object?>> messages,
  ModelConfig config,
) async {
  final selection =
      'SELECT id FROM agent_runs WHERE conversation_id = ? '
      "AND provider = ? AND model = ? AND status = 'completed' "
      'AND id IN (SELECT run_id FROM messages WHERE conversation_id = ? AND created_at >= ?)';
  final args = [
    conversationId,
    config.service.name,
    config.model,
    conversationId,
    messages.last['created_at'],
  ];
  final rows = await database.query(
    'model_turns',
    where: 'run_id IN ($selection)',
    whereArgs: args,
    orderBy: 'ordinal',
  );
  final turns = <String, List<Map<String, Object?>>>{};
  for (final row in rows) {
    turns.putIfAbsent(row['run_id']! as String, () => []).add(row);
  }
  final inputs = <String, List<Map<String, Object?>>>{};
  for (final entry in turns.entries) {
    if (entry.value.any((t) => t['response_json'] == null)) continue;
    final items = <Map<String, Object?>>[];
    final pending = <String>{};
    for (final turn in entry.value) {
      final response = jsonDecode(turn['response_json']! as String) as Map;
      final input = (response['input'] as List).cast<Map>();
      for (final item in input) {
        if (item['type'] == 'function_call_output')
          pending.remove(item['call_id']);
        items.add(item.cast<String, Object?>());
      }
      for (final item in (response['output'] as List).cast<Map>()) {
        if (item['type'] == 'function_call')
          pending.add(item['call_id'] as String);
        items.add(item.cast<String, Object?>());
      }
    }
    final complete = pending.isEmpty;
    if (complete) inputs[entry.key] = items;
  }
  final replay = <String, List<Map<String, Object?>>>{};
  final attached = <String>{};
  // The caller supplies newest first: anchor at the last visible message so a
  // summary checkpoint cannot retain half of a function call/result exchange.
  for (final message in messages) {
    final run = message['run_id'] as String?;
    if (message['role'] != 'assistant' || !inputs.containsKey(run)) continue;
    replay[message['id']! as String] = attached.add(run!) ? inputs[run]! : [];
  }
  return replay;
}
