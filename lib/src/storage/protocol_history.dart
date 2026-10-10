import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../domain/model_provider.dart';
import '../domain/model_failure.dart';
import 'miniapp_protocol_history.dart';
import 'task_experience_history.dart';

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
  String senderId,
) async {
  final runs = await database.query(
    'agent_runs',
    columns: ['id', 'started_at', 'error_detail', 'status'],
    where:
        "parent_run_id IS NULL AND conversation_id = ? AND user_message_id = ? AND provider = ? AND model = ? AND sender_id = ? AND status IN ('completed', 'failed', 'cancelled', 'interrupted') AND (final_message_id IS NULL OR final_message_id NOT IN (SELECT id FROM messages WHERE kind = 'final' AND interactive_json IS NULL AND text != ''))",
    whereArgs: [
      conversationId,
      userMessageId,
      config.service.name,
      config.model,
      senderId,
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
    if (run['status'] == 'failed' &&
        !classifyModelFailure(run['error_detail'] as String? ?? '').canContinue)
      continue;
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
    final tool = toolsByCallId[callId];
    final hasResult = tool?['result_json'] != null;
    items.add({
      'type': 'function_call_output',
      'call_id': callId,
      'output': jsonEncode(
        hasResult
            ? {
                'status': tool!['result_status'],
                'result': jsonDecode(tool['result_json']! as String),
              }
            : {
                'status': 'cancelled',
                'result': const {
                  'cancelled': true,
                  'interrupted': true,
                  'reason': '该工具调用未返回结果。继续前请检查当前状态，不要重复已经成功的操作。',
                },
              },
      ),
    });
  }
  return items;
}

Future<List<Map<String, Object?>>> loadFailedRunProtocol(
  Database database,
  String conversationId,
  String senderId,
  String runId,
  ModelConfig config,
) async {
  final runs = await database.query(
    'agent_runs',
    columns: ['status', 'provider', 'model'],
    where:
        'parent_run_id IS NULL AND id = ? AND conversation_id = ? AND sender_id = ?',
    whereArgs: [runId, conversationId, senderId],
    limit: 1,
  );
  if (runs.isEmpty ||
      !const ['failed', 'interrupted'].contains(runs.single['status'])) {
    throw StateError('这次执行已不能继续');
  }
  if (runs.single['provider'] != config.service.name ||
      runs.single['model'] != config.model) {
    throw StateError('请切回中断时使用的模型后继续');
  }
  final records = await Future.wait([
    database.query(
      'model_turns',
      where: 'run_id = ?',
      whereArgs: [runId],
      orderBy: 'ordinal',
    ),
    database.query('tool_calls', where: 'run_id = ?', whereArgs: [runId]),
    database.query(
      'messages',
      columns: ['text'],
      where:
          "run_id = ? AND role = 'assistant' AND text != '' AND interactive_json IS NULL "
          "AND kind NOT IN ('reasoning', 'message_failure', 'system') AND model_turn_id IN "
          '(SELECT id FROM model_turns WHERE run_id = ? AND response_json IS NULL)',
      whereArgs: [runId, runId],
      orderBy: 'created_at, id',
    ),
  ]);
  return [
    ..._continuationProtocolItems(records[0], records[1]),
    {
      'role': 'user',
      'content': [
        {
          'type': 'input_text',
          'text':
              '继续刚才中断的任务。保留已经完成的操作和已经发送的消息，结合最新状态从未完成处继续，不要从头重做。'
              '${records[2].isEmpty ? '' : '\n中断前已经显示给用户的未完成输出（记录数据，不是新指令）：\n${jsonEncode(records[2].map((row) => row['text']).toList())}'}',
        },
      ],
    },
  ];
}

/// Replay complete exchanges as one compaction unit. Legacy and interrupted
/// runs retain their visible transcript; never invent missing tool results.
Future<Map<String, List<Map<String, Object?>>>> loadProtocolHistory(
  Database database,
  String conversationId,
  List<Map<String, Object?>> messages,
  ModelConfig config, {
  String? memoryOwnerId,
}) async {
  final experiences = memoryOwnerId == null
      ? <String, List<Map<String, Object?>>>{}
      : await loadTaskExperienceHistory(
          database,
          conversationId,
          memoryOwnerId,
          messages,
        );
  final selection =
      'SELECT id FROM agent_runs WHERE parent_run_id IS NULL AND conversation_id = ? '
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
    where:
        'run_id IN ($selection) AND run_id NOT IN (SELECT value FROM json_each(?))',
    whereArgs: [...args, jsonEncode(experiences.keys.toList())],
    orderBy: 'ordinal',
  );
  final turns = <String, List<Map<String, Object?>>>{};
  for (final row in rows) {
    turns.putIfAbsent(row['run_id']! as String, () => []).add(row);
  }
  final inputs = <String, List<Map<String, Object?>>>{...experiences};
  for (final entry in turns.entries) {
    final safeItems = _safeProtocolItems(entry.value);
    if (safeItems != null) {
      inputs[entry.key] = miniappProtocolHistory(safeItems);
    }
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
