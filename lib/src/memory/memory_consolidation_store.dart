import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../domain/agent_models.dart';
import 'memory_evidence.dart';
import 'memory_search.dart';

class MemoryWriteConflict implements Exception {
  const MemoryWriteConflict();
  @override
  String toString() => '记忆版本冲突，整理结果尚未写入';
}

class MemoryConsolidationStore {
  MemoryConsolidationStore(this.database);
  final Database database;

  Future<bool> commit(
    Map<String, Object?> job,
    MemoryEvidence evidence,
    List<Map<String, Object?>> changes,
  ) => database.transaction((txn) async {
    final liveJob = await txn.query(
      'memory_jobs',
      columns: ['cursor', 'state'],
      where: 'run_id = ?',
      whereArgs: [job['run_id']],
      limit: 1,
    );
    if (liveJob.isEmpty ||
        liveJob.single['state'] != 'working' ||
        liveJob.single['cursor'] != job['cursor'])
      return false;
    final owner = job['owner_id'];
    final ids = changes
        .expand((c) => (c['ids'] as List).cast<String>())
        .toSet();
    final fingerprints = [
      for (final c in changes) memoryFingerprint(c['text'] as String),
    ];
    final replacementRows = await txn.query(
      'user_memories',
      where: 'owner_id = ? AND id IN (SELECT value FROM json_each(?))',
      whereArgs: [owner, jsonEncode(ids.toList())],
      limit: 96,
    );
    final duplicateRows = await txn.query(
      'user_memories',
      where:
          "owner_id = ? AND state = 'active' AND fingerprint IN (SELECT value FROM json_each(?))",
      whereArgs: [owner, jsonEncode(fingerprints)],
      orderBy: 'updated_at DESC, id',
      limit: 100,
    );
    final current = [...duplicateRows, ...replacementRows];
    final byId = {for (final row in current) row['id']: row};
    final keys = {
      'run:${job['run_id']}',
      for (final r in evidence.records) r['source'],
    };
    final tombstones = await txn.query(
      'memory_tombstones',
      columns: ['source_key'],
      where: 'owner_id = ? AND source_key IN (SELECT value FROM json_each(?))',
      whereArgs: [owner, jsonEncode(keys.toList())],
    );
    final forbidden = tombstones.map((r) => r['source_key']).toSet();
    final latest = await txn.rawQuery(
      '''SELECT kind || ':' || source_id AS source_key, MAX(id) AS id
      FROM memory_evidence WHERE run_id = ? AND kind || ':' || source_id IN (SELECT value FROM json_each(?))
      GROUP BY kind, source_id''',
      [job['run_id'], jsonEncode(keys.toList())],
    );
    final versions = {for (final r in latest) r['source_key']: r['id']};
    final messageRecords = evidence.records
        .where((r) => r.containsKey('contentFingerprint'))
        .toList();
    final liveMessages = await txn.query(
      'messages',
      columns: ['id', 'text'],
      where: 'id IN (SELECT value FROM json_each(?))',
      whereArgs: [jsonEncode(messageRecords.map((r) => r['id']).toList())],
    );
    final fingerprintsNow = {
      for (final row in liveMessages)
        row['id']: memoryFingerprint(row['text'] as String),
    };
    if (evidence.records.any((r) => versions[r['source']] != r['event']) ||
        messageRecords.any(
          (r) => fingerprintsNow[r['id']] != r['contentFingerprint'],
        )) {
      await txn.update(
        'memory_jobs',
        {'state': 'pending', 'due_at': 0},
        where: 'run_id = ?',
        whereArgs: [job['run_id']],
      );
      return false;
    }
    final records = {
      for (final r in evidence.records) r['source'] as String: r,
    };
    final batch = txn.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    final transfers = <Map<String, String>>[];
    final jobScope = job['scope'] as String;
    final known = {
      for (final r in current)
        if (r['state'] == 'active')
          '${r['fingerprint']}:${r['kind']}:${r['assertion']}': r['id'],
    };
    for (final change in changes) {
      final replace = (change['ids'] as List).cast<String>();
      final expected = (change['versions'] as List).cast<int>();
      final sources = (change['sources'] as List).cast<String>();
      final text = change['text'] as String;
      final fingerprint = memoryFingerprint(text);
      final duplicateKey =
          '$fingerprint:${change['kind']}:${change['assertion']}';
      if (forbidden.contains('run:${job['run_id']}') ||
          sources.any(forbidden.contains))
        continue;
      for (var i = 0; i < replace.length; i++) {
        final row = byId[replace[i]];
        if (row == null ||
            row['version'] != expected[i] ||
            row['manual'] == 1 ||
            row['state'] != 'active') {
          throw const MemoryWriteConflict();
        }
      }
      final duplicate = known[duplicateKey] as String?;
      final id = duplicate ?? newMessageId();
      final sourceScope =
          replace.any((old) => byId[old]!['memory_scope'] != jobScope)
          ? ''
          : jobScope;
      if (duplicate == null) {
        batch.insert('user_memories', {
          'id': id,
          'owner_id': owner,
          'memory_scope': sourceScope,
          'text': text,
          'manual': 0,
          'kind': change['kind'],
          'assertion': change['assertion'],
          'created_at': now,
          'updated_at': now,
          'source_conversation_id': job['conversation_id'],
          ...memorySearchColumns(
            text,
            keywords: (change['keywords'] as List).cast<String>(),
            entities: (change['entities'] as List)
                .map((e) => Map<String, Object?>.from(e as Map))
                .toList(),
          ),
        });
        known[duplicateKey] = id;
      } else {
        batch.update(
          'user_memories',
          {
            'last_used_at': now,
            if (byId[id] != null && byId[id]!['memory_scope'] != sourceScope)
              'memory_scope': '',
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      for (final oldId in replace.where((oldId) => oldId != id)) {
        batch.update(
          'user_memories',
          {
            'state': 'superseded',
            'superseded_by': id,
            'version': (byId[oldId]!['version'] as int) + 1,
          },
          where: 'id = ?',
          whereArgs: [oldId],
        );
      }
      transfers.addAll(replace.map((oldId) => {'old': oldId, 'next': id}));
      for (final source in sources) {
        final event = evidence.events.lastWhere(
          (e) => '${e['kind']}:${e['source_id']}' == source,
        );
        batch.insert('memory_sources', {
          'memory_id': id,
          'source_key': source,
          'conversation_id': job['conversation_id'],
          'run_id': records[source]!['source_run_id'] ?? job['run_id'],
          'event_id': records[source]!['event'],
          if (event['kind'] == 'message') 'message_id': event['source_id'],
          if (event['kind'] == 'tool') 'tool_call_id': event['source_id'],
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
    batch.rawInsert(
      r'''INSERT OR IGNORE INTO memory_sources
      SELECT json_extract(t.value, '$.next'), s.source_key, s.conversation_id, s.run_id, s.message_id, s.tool_call_id, s.event_id
      FROM json_each(?) t INNER JOIN memory_sources s ON s.memory_id = json_extract(t.value, '$.old')''',
      [jsonEncode(transfers)],
    );
    batch.update(
      'memory_jobs',
      {
        'cursor': evidence.cursor,
        'state': 'done',
        'due_at': 0,
        'error': null,
        'conflicts': 0,
      },
      where: 'run_id = ?',
      whereArgs: [job['run_id']],
    );
    await batch.commit(noResult: true);
    await txn.rawUpdate(
      "UPDATE memory_jobs SET state = CASE WHEN EXISTS(SELECT 1 FROM agent_runs WHERE id = ? AND status = 'running') THEN 'waiting' WHEN EXISTS(SELECT 1 FROM memory_evidence WHERE run_id = ? AND id > ?) THEN 'pending' ELSE 'done' END WHERE run_id = ?",
      [job['run_id'], job['run_id'], evidence.cursor, job['run_id']],
    );
    return changes.isNotEmpty;
  });
}
