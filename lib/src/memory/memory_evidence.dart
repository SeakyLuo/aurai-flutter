import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../domain/interactive_message.dart';
import 'memory_search.dart';

class MemoryEvidence {
  MemoryEvidence(
    this.events,
    this.records,
    this.cursor, {
    this.offset = 0,
    this.context = const [],
    this.fingerprint,
  });
  final List<Map<String, Object?>> events, records, context;
  final int cursor, offset;
  final String? fingerprint;

  Map<String, Object?> toJson() => {
    'events': events,
    'records': records,
    'cursor': cursor,
    'offset': offset,
    'context': context,
    'fingerprint': fingerprint,
  };

  factory MemoryEvidence.fromJson(String value) {
    final data = jsonDecode(value) as Map;
    List<Map<String, Object?>> rows(String key) => (data[key] as List)
        .map((r) => Map<String, Object?>.from(r as Map))
        .toList();
    return MemoryEvidence(
      rows('events'),
      rows('records'),
      data['cursor'] as int,
      offset: data['offset'] as int,
      context: rows('context'),
      fingerprint: data['fingerprint'] as String?,
    );
  }

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
      orderBy: 'id',
      limit: 16,
    );
    if (batch.isEmpty) return MemoryEvidence([], [], job['cursor'] as int);
    final results = await Future.wait([
      db.query(
        'messages',
        where: 'id IN (SELECT value FROM json_each(?))',
        whereArgs: [
          jsonEncode(
            batch
                .where((e) => e['kind'] == 'message')
                .map((e) => e['source_id'])
                .toList(),
          ),
        ],
      ),
      db.query(
        'tool_calls',
        where: 'id IN (SELECT value FROM json_each(?))',
        whereArgs: [
          jsonEncode(
            batch
                .where((e) => e['kind'] == 'tool')
                .map((e) => e['source_id'])
                .toList(),
          ),
        ],
      ),
    ]);
    final messages = {for (final row in results[0]) row['id']: row};
    final tools = {for (final row in results[1]) row['id']: row};
    // Context only includes messages this owner actually observed; no arbitrary group history.
    final history = await db.rawQuery(
      """SELECT id, text, role, sender_id, interactive_json FROM messages
      WHERE id IN (SELECT source_id FROM memory_evidence WHERE kind = 'message' AND id < ?
        AND run_id IN (SELECT run_id FROM memory_jobs WHERE owner_id = ? AND conversation_id = ?))
      AND kind != 'reasoning' ORDER BY created_at DESC, id DESC LIMIT 8""",
      [batch.first['id'], job['owner_id'], job['conversation_id']],
    );
    final details = await Future.wait([
      db.query(
        'message_senders',
        columns: ['id', 'name'],
        where: 'id IN (SELECT value FROM json_each(?))',
        whereArgs: [
          jsonEncode(
            [
              ...messages.values,
              ...history,
            ].map((r) => r['sender_id']).toSet().toList(),
          ),
        ],
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
    ]);
    final names = {for (final row in details[0]) row['id']: row['name']};
    final origins = {for (final row in details[1]) row['message_id']: row};
    bool visible(Map<String, Object?> row) {
      final metadata = row['interactive_json'] as String?;
      return metadata == null ||
          InteractiveMessage.fromJson(
            Map<String, Object?>.from(jsonDecode(metadata) as Map),
          ).canView(job['owner_id'] as String);
    }

    final context = [
      for (final row in history.reversed)
        if (visible(row))
          {
            'speaker_name': names[row['sender_id']],
            'role': row['role'],
            'text': _excerpt(row['text'] as String, 1200),
          },
    ];
    final records = <Map<String, Object?>>[];
    final events = <Map<String, Object?>>[];
    var cursor = job['cursor'] as int;
    var offset = job['text_offset'] as int;
    var remaining = 24000;
    String? fingerprint;
    // Consume oldest evidence first. Only tools may be excerpted; messages resume at a saved offset.
    for (final event in batch) {
      final id = event['source_id'];
      final base = {'source': '${event['kind']}:$id', 'event': event['id']};
      Map<String, Object?>? record;
      var nextOffset = 0;
      if (event['kind'] == 'message' &&
          messages.containsKey(id) &&
          visible(messages[id]!)) {
        final row = messages[id]!;
        final text = row['text'] as String;
        final currentFingerprint = memoryFingerprint(text);
        final start =
            offset != 0 && job['text_fingerprint'] == currentFingerprint
            ? offset
            : 0;
        if (start > 0) {
          context.add({
            'role': row['role'],
            'speaker_name': names[row['sender_id']],
            'text': text.substring((start - 1200).clamp(0, start), start),
          });
        }
        final end = (start + 8000).clamp(0, text.length);
        record = {
          ...base,
          'id': id,
          'text': text.substring(start, end),
          'role': row['role'],
          'kind': row['kind'],
          'source_run_id': row['run_id'] ?? runId,
          'contentFingerprint': memoryFingerprint(text),
          'authored_by': origins[id]?['author_id'] ?? row['sender_id'],
          'speaker_name': names[row['sender_id']],
          if (origins.containsKey(id)) 'delegation': true,
          'segment_start': start,
          'segment_end': end,
          'message_length': text.length,
          'attachments': details[2]
              .where((a) => a['message_id'] == id)
              .toList(),
        };
        if (end < text.length) {
          nextOffset = end;
          fingerprint = currentFingerprint;
        }
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
      if (record != null) {
        final cost = jsonEncode(record).length;
        if (records.isNotEmpty && cost > remaining) break;
        remaining -= cost;
        records.add(record);
        events.add(event);
      }
      offset = nextOffset;
      if (offset != 0) break;
      cursor = event['id'] as int;
    }
    return MemoryEvidence(
      events,
      records,
      cursor,
      offset: offset,
      context: context,
      fingerprint: fingerprint,
    );
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
