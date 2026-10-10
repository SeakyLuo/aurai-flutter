import 'dart:async';
import 'dart:convert';
import '../memory/memory_events.dart';
import 'package:sqflite/sqflite.dart';
import '../domain/agent_models.dart';
import '../domain/tool_models.dart';

const subagentRunSchema = [
  'ALTER TABLE agent_runs ADD COLUMN parent_run_id TEXT REFERENCES agent_runs(id) ON DELETE CASCADE',
  'ALTER TABLE agent_runs ADD COLUMN parent_tool_call_id TEXT REFERENCES tool_calls(id) ON DELETE CASCADE',
  'CREATE INDEX run_parent_tool ON agent_runs(parent_tool_call_id)',
];

class SubagentRuns {
  SubagentRuns(this.database);
  final Database database;
  static final _changes = StreamController<String>.broadcast();
  Stream<String> get changes => _changes.stream;
  void changed(String runId) => _changes.add(runId);

  Future<String> start(String parentRunId, ToolCall call) async {
    final parent = (await database.query(
      'agent_runs',
      where: 'id = ? AND parent_run_id IS NULL',
      whereArgs: [parentRunId],
      limit: 1,
    )).single;
    final id = newMessageId();
    final config = jsonDecode(parent['configuration_json'] as String) as Map;
    await database.insert('agent_runs', {
      'id': id,
      'conversation_id': parent['conversation_id'],
      'user_message_id': parent['user_message_id'],
      'sender_id': parent['sender_id'],
      'provider': parent['provider'],
      'model': parent['model'],
      'configuration_json': jsonEncode({
        ...config,
        'delegation': call.arguments,
      }),
      'parent_run_id': parentRunId,
      'parent_tool_call_id': '$parentRunId:${call.id}',
      'status': 'running',
      'started_at': DateTime.now().microsecondsSinceEpoch,
    });
    return id;
  }

  Future<void> finish(
    String id,
    String status,
    int elapsed, {
    String? error,
  }) async {
    await database.transaction((txn) async {
      final batch = txn.batch();
      final now = DateTime.now().microsecondsSinceEpoch;
      batch.update(
        'agent_runs',
        {
          'status': status,
          'elapsed_ms': elapsed,
          'error_detail': error,
          'finished_at': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      batch.update(
        'model_turns',
        {'status': status, 'finished_at': now},
        where: 'run_id = ? AND status = ?',
        whereArgs: [id, 'running'],
      );
      batch.update(
        'tool_calls',
        {
          'status': status == 'cancelled' ? 'cancelled' : 'failed',
          'finished_at': now,
        },
        where: 'run_id = ? AND status = ?',
        whereArgs: [id, 'running'],
      );
      batch.update(
        'tool_approvals',
        {'decision': 'interrupted', 'resolved_at': now},
        where:
            "decision = 'pending' AND tool_call_id IN (SELECT id FROM tool_calls WHERE run_id = ?)",
        whereArgs: [id],
      );
      await batch.commit(noResult: true);
    });
    changed(id);
    MemoryEvents.wakeQueue();
  }

  Future<List<Map<String, Object?>>> tools(String runId) => database.query(
    'tool_calls',
    where: 'run_id = ?',
    whereArgs: [runId],
    orderBy: 'started_at',
    limit: 200,
  );
  Future<Map<String, Object?>> read(String runId) async =>
      (await database.query(
        'agent_runs',
        where: 'id = ? AND parent_run_id IS NOT NULL',
        whereArgs: [runId],
        limit: 1,
      )).single;
}
