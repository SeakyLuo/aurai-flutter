import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../domain/model_provider.dart';

List<Map<String, Object?>>? _safeProtocolItems(
  Iterable<Map<String, Object?>> turns,
) {
  final items = <Map<String, Object?>>[];
  List<Map<String, Object?>>? safeItems;
  final pending = <String>{};
  for (final turn in turns) {
    if (turn['response_json'] == null) break;
    final response = jsonDecode(turn['response_json']! as String) as Map;
    final input = (response['input'] as List).cast<Map>();
    for (final item in input) {
      if (item['type'] == 'function_call_output') {
        pending.remove(item['call_id']);
      }
      items.add(item.cast<String, Object?>());
    }
    if (pending.isEmpty) safeItems = List.of(items);
    for (final item in (response['output'] as List).cast<Map>()) {
      if (item['type'] == 'function_call') {
        pending.add(item['call_id'] as String);
      }
      items.add(item.cast<String, Object?>());
    }
    if (pending.isEmpty) safeItems = List.of(items);
  }
  return safeItems;
}

Future<List<Map<String, Object?>>> loadTaskContinuationProtocol(
  Database database,
  String conversationId,
  String userMessageId,
  ModelConfig config,
) async {
  final runs = await database.query(
    'agent_runs',
    columns: ['id', 'started_at'],
    where:
        "conversation_id = ? AND user_message_id = ? AND provider = ? AND model = ? AND status IN ('completed', 'failed', 'cancelled', 'interrupted') AND (final_message_id IS NULL OR final_message_id NOT IN (SELECT id FROM messages WHERE kind = 'final' AND interactive_json IS NULL AND text != ''))",
    whereArgs: [
      conversationId,
      userMessageId,
      config.service.name,
      config.model,
    ],
    orderBy: 'started_at DESC, id DESC',
  );
  if (runs.isEmpty) return const [];
  final runIds = runs.map((run) => run['id']).toList();
  final turnRows = await database.query(
    'model_turns',
    where: 'run_id IN (${List.filled(runIds.length, '?').join(', ')})',
    whereArgs: runIds,
    orderBy: 'ordinal',
  );
  final toolRows = await database.query(
    'tool_calls',
    where: 'run_id IN (${List.filled(runIds.length, '?').join(', ')})',
    whereArgs: runIds,
  );
  final turns = <Object, List<Map<String, Object?>>>{};
  for (final row in turnRows) {
    turns.putIfAbsent(row['run_id']!, () => []).add(row);
  }
  final tools = <Object, List<Map<String, Object?>>>{};
  for (final row in toolRows) {
    tools.putIfAbsent(row['run_id']!, () => []).add(row);
  }
  final orderedRuns = runs.toList()
    ..sort((a, b) {
      final aCompleted = (tools[a['id']] ?? const [])
          .where((tool) => tool['status'] == 'completed')
          .length;
      final bCompleted = (tools[b['id']] ?? const [])
          .where((tool) => tool['status'] == 'completed')
          .length;
      final progress = bCompleted.compareTo(aCompleted);
      if (progress != 0) return progress;
      return (b['started_at']! as int).compareTo(a['started_at']! as int);
    });
  for (final run in orderedRuns) {
    final items = _continuationProtocolItems(
      turns[run['id']] ?? const <Map<String, Object?>>[],
      tools[run['id']] ?? const <Map<String, Object?>>[],
    );
    if (items.isNotEmpty) return items;
  }
  return const [];
}

List<Map<String, Object?>> _continuationProtocolItems(
  Iterable<Map<String, Object?>> turns,
  Iterable<Map<String, Object?>> tools,
) {
  final items = <Map<String, Object?>>[];
  final pending = <String>{};
  for (final turn in turns) {
    if (turn['response_json'] == null) break;
    final response = jsonDecode(turn['response_json']! as String) as Map;
    for (final item in (response['input'] as List).cast<Map>()) {
      if (item['type'] == 'function_call_output') {
        pending.remove(item['call_id']);
      }
      items.add(item.cast<String, Object?>());
    }
    for (final item in (response['output'] as List).cast<Map>()) {
      if (item['type'] == 'function_call') {
        pending.add(item['call_id'] as String);
      }
      items.add(item.cast<String, Object?>());
    }
  }
  final toolsByCallId = {
    for (final tool in tools) tool['provider_call_id']: tool,
  };
  for (final callId in pending) {
    final tool = toolsByCallId[callId]!;
    final completed = tool['status'] == 'completed';
    items.add({
      'type': 'function_call_output',
      'call_id': callId,
      'output': jsonEncode(
        completed
            ? {
                'status': tool['result_status'],
                'result': jsonDecode(tool['result_json']! as String),
              }
            : {
                'status': 'cancelled',
                'result': const {
                  'cancelled': true,
                  'interrupted': true,
                  'reason': '该工具调用已被终止，未产生结果。',
                },
              },
      ),
    });
  }
  return items;
}

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
      "AND provider = ? AND model = ? AND status IN ('completed', 'failed', 'interrupted') "
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
    final safeItems = _safeProtocolItems(entry.value);
    if (safeItems != null) inputs[entry.key] = safeItems;
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
