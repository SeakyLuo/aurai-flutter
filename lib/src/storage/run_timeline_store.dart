import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../domain/interactive_message.dart';
import '../domain/message_sender.dart';

class RunTimelinePage {
  const RunTimelinePage(
    this.run,
    this.entries,
    this.hasEarlier,
    this.firstEventId,
    this.turnEventIds,
  );
  final Map<String, Object?> run;
  final List<RunTimelineEntry> entries;
  final bool hasEarlier;
  final int? firstEventId;
  final Set<int> turnEventIds;
}

class RunTimelineEntry {
  const RunTimelineEntry(this.eventId, this.message, this.tool);
  final int eventId;
  final Map<String, Object?>? message;
  final Map<String, Object?>? tool;
  int get createdAt => (message?['created_at'] ?? tool!['started_at']) as int;
}

class RunTimelineStore {
  const RunTimelineStore(this.database);
  final Database database;

  Future<bool> hasProcess(String runId) async {
    final rows = await database.rawQuery(
      '''SELECT
      EXISTS(SELECT 1 FROM messages WHERE run_id = ?
        AND kind IN ('commentary', 'reasoning') AND text != '')
      OR EXISTS(SELECT 1 FROM tool_calls WHERE run_id = ?
        AND name != 'sendGroupMessage')
      OR EXISTS(SELECT 1 FROM model_turns t, json_each(t.response_json, '\$.output') item
        WHERE t.run_id = ? AND json_extract(item.value, '\$.type') = 'message'
        AND EXISTS(SELECT 1 FROM json_each(item.value, '\$.content') part
          WHERE json_extract(part.value, '\$.type') = 'output_text'
          AND json_extract(part.value, '\$.text') != ''
          AND NOT EXISTS(SELECT 1 FROM messages m WHERE m.run_id = t.run_id
            AND m.model_turn_id = t.id AND m.role = 'assistant'
            AND m.text = json_extract(part.value, '\$.text')))) AS present''',
      [runId, runId, runId],
    );
    return rows.single['present'] == 1;
  }

  Future<RunTimelinePage> read(String runId, {int? before}) async {
    final results = await Future.wait([
      database.query(
        'agent_runs',
        columns: ['id', 'conversation_id', 'status', 'elapsed_ms'],
        where: 'id = ?',
        whereArgs: [runId],
        limit: 1,
      ),
      database.query(
        'run_events',
        where: 'run_id = ?${before == null ? '' : ' AND id < ?'}',
        whereArgs: [runId, if (before != null) before],
        orderBy: 'id DESC',
        limit: 61,
      ),
    ]);
    if (results[0].isEmpty) throw StateError('这条消息的任务记录已被删除');
    final run = results[0].single;
    final events = results[1].take(60).toList().reversed.toList();
    final messageIds = [
      for (final event in events)
        if (event['message_id'] != null) event['message_id'],
    ];
    final toolIds = [
      for (final event in events)
        if (event['tool_call_id'] != null) event['tool_call_id'],
    ];
    final payloads = await Future.wait([
      messageIds.isEmpty
          ? Future.value(<Map<String, Object?>>[])
          : database.query(
              'messages',
              where:
                  'run_id = ? AND id IN (${List.filled(messageIds.length, '?').join(',')})',
              whereArgs: [runId, ...messageIds],
            ),
      toolIds.isEmpty
          ? Future.value(<Map<String, Object?>>[])
          : database.query(
              'tool_calls',
              where:
                  'run_id = ? AND id IN (${List.filled(toolIds.length, '?').join(',')})',
              whereArgs: [runId, ...toolIds],
            ),
    ]);
    final messages = {for (final row in payloads[0]) row['id']: row};
    final tools = {for (final row in payloads[1]) row['id']: row};
    final turnIds = {
      for (final row in [...payloads[0], ...payloads[1]])
        if (row['model_turn_id'] != null) row['model_turn_id'],
    };
    final turns = await database.query(
      'model_turns',
      columns: ['id', 'ordinal', 'started_at', 'response_json'],
      where:
          'run_id = ? AND (id IN (${turnIds.isEmpty ? 'NULL' : List.filled(turnIds.length, '?').join(',')}) '
          '${before == null ? 'OR id = (SELECT id FROM model_turns WHERE run_id = ? ORDER BY ordinal DESC LIMIT 1)' : ''})',
      whereArgs: [runId, ...turnIds, if (before == null) runId],
      limit: 61,
    );
    final entries = <RunTimelineEntry>[];
    for (final turn in turns) {
      final responseJson = turn['response_json'] as String?;
      if (responseJson == null) continue;
      final response = jsonDecode(responseJson) as Map;
      final text = (response['output'] as List)
          .cast<Map>()
          .where((item) => item['type'] == 'message')
          .expand((item) => (item['content'] as List).cast<Map>())
          .where(
            (part) =>
                part['type'] == 'output_text' || part['type'] == 'refusal',
          )
          .map((part) => (part['text'] ?? part['refusal']) as String)
          .join('\n\n');
      if (text.isEmpty) continue;
      entries.add(
        RunTimelineEntry(-(turn['ordinal'] as int) - 1, {
          'id': 'turn:${turn['ordinal']}',
          'model_turn_id': turn['id'],
          'kind': 'commentary',
          'text': text,
          'created_at': turn['started_at'],
        }, null),
      );
    }
    // A model response can also be persisted as a delivered message.
    // Check the whole run so paging does not show the same reply twice.
    if (entries.isNotEmpty) {
      final delivered = await database.query(
        'messages',
        distinct: true,
        columns: ['model_turn_id', 'text'],
        where:
            "run_id = ? AND role = 'assistant' AND EXISTS (SELECT 1 FROM json_each(?) expected WHERE json_extract(expected.value, '\$.turn') = messages.model_turn_id AND json_extract(expected.value, '\$.text') = messages.text)",
        whereArgs: [
          runId,
          jsonEncode([
            for (final entry in entries)
              {
                'turn': entry.message!['model_turn_id'],
                'text': entry.message!['text'],
              },
          ]),
        ],
        limit: entries.length,
      );
      final texts = delivered
          .map((message) => (message['model_turn_id'], message['text']))
          .toSet();
      entries.removeWhere(
        (entry) => texts.contains((
          entry.message!['model_turn_id'],
          entry.message!['text'],
        )),
      );
    }
    for (final event in events) {
      final message = messages[event['message_id']];
      final tool = tools[event['tool_call_id']];
      if (message != null) {
        final metadata = message['interactive_json'] as String?;
        if (metadata != null &&
            !InteractiveMessage.fromJson(
              jsonDecode(metadata) as Map<String, dynamic>,
            ).canView(MessageSender.localUser.id)) {
          continue;
        }
        entries.add(RunTimelineEntry(event['id'] as int, message, null));
      } else if (tool != null) {
        entries.add(RunTimelineEntry(event['id'] as int, null, tool));
      }
    }
    return RunTimelinePage(
      run,
      entries,
      results[1].length > 60,
      events.isEmpty ? null : events.first['id'] as int,
      {for (final turn in turns) -(turn['ordinal'] as int) - 1},
    );
  }
}
