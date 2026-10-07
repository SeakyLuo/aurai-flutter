import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../domain/interactive_message.dart';
import 'memory_search.dart';

class MemoryEvidence {
  MemoryEvidence(this.events, this.records, this.cursor);
  final List<Map<String, Object?>> events, records;
  final int cursor;

  static Future<MemoryEvidence> read(
    Database db,
    Map<String, Object?> job, {
    int? through,
  }) async {
    final runId = job['run_id'];
    final batch = await db.query(
      'memory_evidence',
      where: 'run_id = ? AND id > ?' + (through == null ? '' : ' AND id <= ?'),
      whereArgs: [runId, job['cursor'], if (through != null) through],
      orderBy: 'id DESC',
      limit: 16,
    );
    if (batch.isEmpty) return MemoryEvidence([], [], job['cursor'] as int);
    final cursor = batch.first['id'] as int;
    final selectedAfter = (batch.last['id'] as int) - 1;
    const messagePool =
        "id IN (SELECT source_id FROM memory_evidence WHERE run_id = ? AND id > ? AND id <= ? AND kind = 'message') AND kind != 'reasoning'";
    const toolPool =
        "id IN (SELECT source_id FROM memory_evidence WHERE run_id = ? AND id > ? AND id <= ? AND kind = 'tool')";
    final results = await Future.wait([
      db.query(
        'messages',
        where: "($messagePool) AND role = 'user'",
        whereArgs: [runId, selectedAfter, cursor],
        orderBy: 'created_at DESC, id',
        limit: 16,
      ),
      db.query(
        'messages',
        where: "($messagePool) AND role = 'assistant'",
        whereArgs: [runId, selectedAfter, cursor],
        orderBy:
            "CASE WHEN kind = 'final' THEN 0 ELSE 1 END, created_at DESC, id",
        limit: 16,
      ),
      db.query(
        'messages',
        where: 'id IN (SELECT user_message_id FROM agent_runs WHERE id = ?)',
        whereArgs: [runId],
        limit: 1,
      ),
      db.query(
        'tool_calls',
        where:
            "($toolPool) AND status != 'completed' AND result_status != 'success'",
        whereArgs: [runId, selectedAfter, cursor],
        orderBy: 'finished_at DESC, id',
        limit: 16,
      ),
      db.query(
        'tool_calls',
        where: toolPool,
        whereArgs: [runId, selectedAfter, cursor],
        orderBy: 'finished_at DESC, id',
        limit: 16,
      ),
      db.query(
        'agent_runs',
        columns: ['id', 'status', 'parent_run_id', 'error_detail'],
        where: 'id = ?',
        whereArgs: [runId],
        limit: 1,
      ),
    ]);
    final messages = <Object?, Map<String, Object?>>{};
    for (final row in [...results[0], ...results[1], ...results[2]]) {
      final metadata = row['interactive_json'] as String?;
      if (metadata != null &&
          !InteractiveMessage.fromJson(
            Map<String, Object?>.from(jsonDecode(metadata) as Map),
          ).canView(job['owner_id'] as String))
        continue;
      messages[row['id']] = row;
    }
    final tools = {
      for (final row in [...results[3], ...results[4]]) row['id']: row,
    };
    final sourceKeys = [
      'run:$runId',
      for (final id in messages.keys) 'message:$id',
      for (final id in tools.keys) 'tool:$id',
    ];
    final details = await Future.wait([
      db.rawQuery(
        '''SELECT MAX(id) AS id, kind, source_id FROM memory_evidence
        WHERE run_id = ? AND id <= ? AND kind || ':' || source_id IN (SELECT value FROM json_each(?))
        GROUP BY kind, source_id''',
        [runId, cursor, jsonEncode(sourceKeys)],
      ),
      db.query(
        'memory_message_origins',
        where: 'message_id IN (SELECT value FROM json_each(?))',
        whereArgs: [jsonEncode(messages.keys.toList())],
      ),
      db.query(
        'attachments',
        columns: ['id', 'message_id', 'kind', 'display_name', 'mime_type'],
        where: 'message_id IN (SELECT value FROM json_each(?))',
        whereArgs: [jsonEncode(messages.keys.toList())],
        limit: 24,
      ),
      db.query(
        'message_senders',
        columns: ['id', 'name'],
        where: 'id IN (SELECT value FROM json_each(?))',
        whereArgs: [
          jsonEncode(
            messages.values.map((r) => r['sender_id']).toSet().toList(),
          ),
        ],
      ),
    ]);
    final events = details[0];
    final origins = {for (final row in details[1]) row['message_id']: row};
    final names = {for (final row in details[3]) row['id']: row['name']};
    final records = <Map<String, Object?>>[];
    var remaining = 24000;
    // One bounded evidence package per continuous execution, not one model request per tool.
    // Long executions sample recent evidence before their window slides; skipped logs remain in the task.
    for (final event in events) {
      final id = event['source_id'];
      final base = {'source': '${event['kind']}:$id', 'event': event['id']};
      Map<String, Object?>? record;
      if (event['kind'] == 'run') {
        record = {
          ...base,
          ...results[5].single,
          'source_run_id': runId,
          'selection':
              'Original logs remain local. This package contains the initial request, recent user updates, final/recent assistant messages and selected failed/recent tools. Omitted steps are not evidence of absence.',
        };
      } else if (event['kind'] == 'message' && messages.containsKey(id)) {
        final row = messages[id]!;
        record = {
          ...base,
          'id': id,
          'text': _excerpt(row['text'] as String, 1600),
          'role': row['role'],
          'kind': row['kind'],
          'source_run_id': row['run_id'] ?? runId,
          'contentFingerprint': memoryFingerprint(row['text'] as String),
          'authored_by': origins[id]?['author_id'] ?? row['sender_id'],
          'speaker_name': names[row['sender_id']],
          if (origins.containsKey(id)) 'delegation': true,
          'attachments': details[2]
              .where((a) => a['message_id'] == id)
              .toList(),
        };
      } else if (event['kind'] == 'tool' && tools.containsKey(id)) {
        final row = tools[id]!;
        record = {
          ...base,
          'name': row['name'],
          'status': row['status'],
          'source_run_id': row['run_id'],
          'arguments': _textObservation(row['arguments_json'] as String, 500),
          'result': _textObservation(row['result_json'] as String?, 1400),
        };
      }
      if (record == null) continue;
      final cost = jsonEncode(record).length;
      if (cost > remaining) continue;
      remaining -= cost;
      records.add(record);
    }
    return MemoryEvidence(events, records, cursor);
  }

  static Object? _textObservation(String? value, int budget) {
    if (value == null) return null;
    Object? clean(Object? node) => switch (node) {
      Map() => {
        for (final entry in node.entries)
          if (!RegExp(
            r'base64|image_url|data_url|api.?key|password|token|secret',
            caseSensitive: false,
          ).hasMatch(entry.key.toString()))
            entry.key.toString(): clean(entry.value),
      },
      List() => node.take(20).map(clean).toList(),
      String() =>
        node.startsWith('data:') ? '[media reference]' : _excerpt(node, budget),
      _ => node,
    };
    return _excerpt(jsonEncode(clean(jsonDecode(value))), budget);
  }

  static String _excerpt(String value, int limit) => value.length <= limit
      ? value
      : '${value.substring(0, limit)}\n[excerpt; consult original source]';
}
