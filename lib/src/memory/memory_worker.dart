import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import '../domain/model_provider.dart';
import '../providers/responses_transport.dart';
import '../providers/model_context_limits.dart';
import 'memory_evidence.dart';
import 'memory_retry.dart';
import 'memory_events.dart';
import 'memory_search.dart';
import 'memory_consolidation_prompt.dart';
import 'memory_consolidation_store.dart';
import 'memory_fragment_validation.dart';

class MemoryWorker {
  MemoryWorker(this.database, this.modelConfig, this.onError);
  final Database database;
  final ModelConfig Function() modelConfig;
  final void Function(Object) onError;
  final _active = <String, ResponsesTransport>{};
  Timer? _timer;
  bool _stopped = false, _polling = false;
  String? _configKey;
  static final _checkpoints = <String, Future<void>>{};

  Future<void> organize(String runId) async {
    final roots = await database.query(
      'agent_runs',
      columns: ['id', 'parent_run_id'],
      where: 'id = ?',
      whereArgs: [runId],
    );
    final mappings = await database.query(
      'memory_run_jobs',
      columns: ['job_id'],
      where: 'run_id = ?',
      whereArgs: [roots.single['parent_run_id'] ?? runId],
    );
    final root = mappings.single['job_id'] as String;
    final previous = _checkpoints[root];
    final finished = Completer<void>();
    _checkpoints[root] = finished.future;
    await previous;
    try {
      final totals = await database.rawQuery(
        'SELECT MAX(id) AS last FROM memory_evidence WHERE run_id = ? AND id > (SELECT cursor FROM memory_jobs WHERE run_id = ?)',
        [root, root],
      );
      final through = totals.single['last'] as int?;
      if (through == null) return;
      if (_stopped) throw StateError('任务整理已取消');
      final rows = await database.query(
        'memory_jobs',
        where: 'run_id = ?',
        whereArgs: [root],
      );
      final job = rows.single;
      final claimed = await database.update(
        'memory_jobs',
        {'state': 'working'},
        where: "run_id = ? AND state != 'working' AND cursor = ?",
        whereArgs: [root, job['cursor']],
      );
      if (claimed != 1) throw StateError('任务记忆正在整理，旧上下文已保留');
      final transport = ResponsesTransport(
        modelConfig(),
        automaticRetries: false,
      );
      _active[root] = transport;
      await _process(job, transport, foreground: true, through: through);
      final saved = await database.query(
        'memory_jobs',
        columns: ['cursor', 'text_offset', 'text_fingerprint'],
        where: 'run_id = ?',
        whereArgs: [root],
      );
      if (saved.single['cursor'] == job['cursor'] &&
          saved.single['text_offset'] == job['text_offset'] &&
          saved.single['text_fingerprint'] == job['text_fingerprint']) {
        throw StateError('任务整理结果未保存，旧上下文已保留');
      }
    } finally {
      finished.complete();
      if (identical(_checkpoints[root], finished.future))
        _checkpoints.remove(root);
    }
  }

  Future<void> start() async {
    await database.update('memory_attempts', {
      'status': 'interrupted',
      'finished_at': DateTime.now().millisecondsSinceEpoch,
    }, where: "status = 'working'");
    await database.update('memory_jobs', {
      'state': 'pending',
    }, where: "state = 'working'");
    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(_poll()),
    );
    unawaited(_poll());
  }

  Future<void> _poll() async {
    if (_stopped || _polling || _active.length >= 2) return;
    _polling = true;
    try {
      final config = modelConfig();
      if (!config.isConfigured) return;
      final key = sha256
          .convert(utf8.encode(jsonEncode(config.toJson())))
          .toString();
      if (_configKey != key) {
        await database.update(
          'memory_jobs',
          {'state': 'pending', 'retries': 0, 'conflicts': 0, 'due_at': 0},
          where: "state = 'failed' AND config_key != ?",
          whereArgs: [key],
        );
        _configKey = key;
      }
      final jobs = await database.query(
        'memory_jobs',
        where:
            "state = 'pending' AND due_at <= ? AND NOT EXISTS (SELECT 1 FROM agent_runs child WHERE (child.id IN (SELECT run_id FROM memory_run_jobs WHERE job_id = memory_jobs.run_id) OR child.parent_run_id IN (SELECT run_id FROM memory_run_jobs WHERE job_id = memory_jobs.run_id)) AND child.status = 'running') AND NOT EXISTS (SELECT 1 FROM memory_jobs older WHERE older.owner_id = memory_jobs.owner_id AND older.conversation_id = memory_jobs.conversation_id AND older.state != 'done' AND older.rowid < memory_jobs.rowid)",
        whereArgs: [DateTime.now().millisecondsSinceEpoch],
        orderBy: 'due_at, run_id',
        limit: 2 - _active.length,
      );
      for (final job in jobs) {
        if (_stopped) break;
        final id = job['run_id'] as String;
        if (_active.containsKey(id)) continue;
        final claimed = await database.update(
          'memory_jobs',
          {'state': 'working'},
          where: "run_id = ? AND state = 'pending'",
          whereArgs: [id],
        );
        if (claimed == 0) continue;
        if (_stopped) break;
        final transport = ResponsesTransport(config, automaticRetries: false);
        _active[id] = transport;
        unawaited(_process(job, transport));
      }
    } on Object catch (error) {
      if (!_stopped) onError(error);
    } finally {
      _polling = false;
    }
  }

  Future<void> _process(
    Map<String, Object?> job,
    ResponsesTransport transport, {
    bool foreground = false,
    int? through,
  }) async {
    final id = job['run_id'] as String;
    int? attempt;
    String? responseId;
    try {
      final evidence = job['batch_json'] != null
          ? MemoryEvidence.fromJson(job['batch_json'] as String)
          : await MemoryEvidence.read(database, job, through: through);
      if (evidence.records.isEmpty &&
          evidence.cursor == job['cursor'] &&
          evidence.offset == job['text_offset']) {
        await database.rawUpdate(
          "UPDATE memory_jobs SET state = CASE WHEN EXISTS(SELECT 1 FROM agent_runs WHERE id IN (SELECT run_id FROM memory_run_jobs WHERE job_id = ?) AND status = 'running') THEN 'waiting' ELSE 'done' END WHERE run_id = ?",
          [id, id],
        );
        return;
      }
      await database.update(
        'memory_jobs',
        {
          'batch_json': jsonEncode(evidence.toJson()),
          'config_key': sha256
              .convert(utf8.encode(jsonEncode(transport.config.toJson())))
              .toString(),
        },
        where: 'run_id = ?',
        whereArgs: [id],
      );
      attempt = await database.insert('memory_attempts', {
        'run_id': id,
        'started_at': DateTime.now().millisecondsSinceEpoch,
        'model': transport.config.apiModel,
        'status': 'working',
        'start_cursor': job['cursor'],
        'end_cursor': evidence.cursor,
        'start_offset': job['text_offset'],
        'end_offset': evidence.offset,
      });
      final search = MemorySearch(
        database,
        job['owner_id'] as String,
        scope: job['scope'] as String,
      );
      final query = evidence.records
          .map(
            (e) =>
                e['text'] ??
                '${e['name'] ?? ''} ${e['arguments'] ?? ''} ${e['result'] ?? ''}',
          )
          .join(' ');
      final candidates = await search.find(
        query.length > 12000 ? query.substring(0, 12000) : query,
        limit: 8,
      );
      List<Map<String, Object?>> changes = [];
      final hasNewContent = evidence.records.any(
        (record) => !(record['source'] as String).startsWith('run:'),
      );
      if (hasNewContent) {
        final response = await transport
            .send({
              'model': transport.config.apiModel,
              ...memoryConsolidationToolFor(
                evidence.records,
                candidates,
              ).request,
              'stream': true,
              // Match the summary budget while respecting the selected model's limit.
              // Reasoning and the structured fragments share this output allowance.
              'max_output_tokens': math.min(
                8192,
                ModelContextLimits.forConfig(transport.config).outputTokens,
              ),
              if (transport.config.service.disableReasoningForSummary)
                'reasoning': {'effort': 'none'},
              'instructions': memoryConsolidationInstructions,
              'input': [
                {
                  'role': 'user',
                  'content': jsonEncode({
                    'owner': job['owner_id'],
                    'scene': job['scope'],
                    'purpose':
                        'Select worthwhile memories from recent evidence, not a task checkpoint or log summary.',
                    'evidence': evidence.records,
                    'context_only': evidence.context,
                    'existing': [
                      for (final e in candidates)
                        {
                          'id': e['id'],
                          'version': e['version'],
                          'text': e['text'],
                          'manual': e['manual'] == 1,
                          'kind': e['kind'],
                          'assertion': e['assertion'],
                          'scope': e['memory_scope'],
                          'entities': jsonDecode(e['entities_json'] as String),
                        },
                    ],
                  }),
                },
              ],
            })
            .timeout(
              const Duration(seconds: 90),
              onTimeout: () async {
                await transport.cancel();
                throw TimeoutException('Memory consolidation timed out');
              },
            );
        responseId = response['id'] as String?;
        if (response['status'] != 'completed') {
          final incomplete = response['incomplete_details'] as Map?;
          final reason = incomplete?['reason'] ?? response['status'];
          throw ModelProviderException(
            '记忆整理未完成（$reason），原始记录和已有记忆已保留',
            detail: jsonEncode(response),
          );
        }
        changes = (memoryConsolidationTool.read(response)['changes'] as List)
            .map((v) => Map<String, Object?>.from(v as Map))
            .toList();
        validateMemoryFragments(changes, candidates, evidence);
      }
      if (_stopped) {
        if (foreground) throw StateError('任务整理已取消');
        return;
      }
      await MemoryConsolidationStore(
        database,
      ).commit(job, evidence, changes, attempt, responseId);
      MemoryEvents.changed(job['owner_id'] as String);
    } on Object catch (error) {
      if (attempt != null) {
        await database.update(
          'memory_attempts',
          {
            'status': _stopped ? 'interrupted' : 'failed',
            'response_id': responseId ?? memoryFailureResponseId(error),
            'error': error.toString(),
            'finished_at': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [attempt],
        );
      }
      if (!_stopped || foreground) {
        final delay = memoryRetryDelay(error, job['retries'] as int);
        if (delay != null) {
          await database.update(
            'memory_jobs',
            {
              'state': 'pending',
              'error': error.toString(),
              'retries': (job['retries'] as int) + 1,
              'due_at':
                  DateTime.now().millisecondsSinceEpoch + delay.inMilliseconds,
            },
            where: 'run_id = ?',
            whereArgs: [id],
          );
          if (foreground) rethrow;
          return;
        }

        if (!foreground &&
            error is MemoryWriteConflict &&
            (job['conflicts'] as int) < 3) {
          await database.update(
            'memory_jobs',
            {
              'state': 'pending',
              'conflicts': (job['conflicts'] as int) + 1,
              'due_at': DateTime.now().millisecondsSinceEpoch + 1000,
            },
            where: 'run_id = ?',
            whereArgs: [id],
          );
          return;
        }
        await database.update(
          'memory_jobs',
          {'state': 'failed', 'error': error.toString()},
          where: 'run_id = ?',
          whereArgs: [id],
        );
        if (foreground) rethrow;
        onError(error);
        MemoryEvents.changed(job['owner_id'] as String);
      }
    } finally {
      _active.remove(id);
    }
  }

  Future<void> cancel() async {
    _stopped = true;
    await Future.wait(_active.values.map((transport) => transport.cancel()));
  }

  void dispose() {
    _stopped = true;
    _timer?.cancel();
    for (final transport in _active.values) {
      unawaited(transport.cancel());
    }
  }
}
