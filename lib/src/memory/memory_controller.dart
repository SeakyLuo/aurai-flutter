import '../providers/structured_result_tool.dart';
import '../domain/local_time.dart';
import '../domain/avatar_style.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../domain/agent_models.dart';
import '../domain/model_provider.dart';
import '../domain/message_sender.dart';
import '../providers/responses_transport.dart';
import '../storage/group_system_notice.dart';
import '../domain/profile_gender.dart';
import 'memory_plan.dart';
import 'memory_search.dart';
import 'memory_worker.dart';
import 'memory_events.dart';
export 'memory_search.dart' show memoryTextLimit;
export 'memory_plan.dart';
part 'memory_retrieval.dart';
part 'memory_planning.dart';
part 'memory_records.dart';

const memorySchema = [
  '''CREATE TABLE memory_settings (id INTEGER PRIMARY KEY CHECK(id=1),
  enabled INTEGER NOT NULL DEFAULT 1, nickname TEXT NOT NULL DEFAULT '',
  occupation TEXT NOT NULL DEFAULT '', about TEXT NOT NULL DEFAULT '',
  gender TEXT NOT NULL DEFAULT 'unknown' CHECK(gender IN ('male', 'female', 'unknown')))''',
  'INSERT INTO memory_settings(id) VALUES(1)',
  '''CREATE TABLE user_memories (id TEXT PRIMARY KEY, text TEXT NOT NULL,
  manual INTEGER NOT NULL, source_conversation_id TEXT, source_message_id TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)''',
];

class MemoryController extends ChangeNotifier {
  MemoryController(
    this.database,
    this.modelConfig, {
    this.ownerId = 'agent:aurai',
    this.scope = '',
  });
  final String ownerId, scope;
  bool get projectShared => ownerId.startsWith('project:');
  String get _scopeWhere =>
      MemorySearch(database, ownerId, scope: scope).visibility;
  List<Object?> get _scopeArgs =>
      MemorySearch(database, ownerId, scope: scope).arguments;
  ModelConfig Function() modelConfig;
  final Database database;
  String nickname = '', occupation = '', about = '';
  ProfileGender gender = ProfileGender.unknown;
  AvatarStyle avatar = const AvatarStyle();
  List<Map<String, Object?>> entries = [];
  int _epoch = 0;
  int get revision => _epoch;
  bool _disposed = false;
  ResponsesTransport? _transport;
  MemoryWorker? _worker;
  final _taskOrganizers = <String, MemoryWorker>{};
  final _taskOrganizationDone = <String, Completer<void>>{};
  StreamSubscription<String>? _changes;
  bool hasMore = false;
  int failedJobs = 0;
  String searchQuery = '';
  final notices = ValueNotifier<String?>(null);

  Future<void> initialize() async {
    final results = await Future.wait([
      database.query('memory_settings', where: 'id = 1'),
      _readRecords(database),
      database.query(
        'message_senders',
        where: 'id = ?',
        whereArgs: ['user:local'],
      ),
    ]);
    final settings = results.first.single;
    nickname = settings['nickname'] as String;
    MessageSender.setLocalUserName(nickname);
    occupation = settings['occupation'] as String;
    gender = ProfileGender.values.byName(settings['gender'] as String);
    about = settings['about'] as String;
    _setEntries(results[1]);
    await _readFailures();
    _changes = MemoryEvents.changes.where((owner) => owner == ownerId).listen((
      _,
    ) {
      unawaited(
        reload().onError((Object error, StackTrace stack) {
          if (!_disposed) notices.value = error.toString();
        }),
      );
    });
    avatar = AvatarStyle.fromRow(results[2].single);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _invalidate() {
    _epoch++;
    unawaited(_transport?.cancel());
  }

  Future<void> saveProfile(
    String name,
    String job,
    String info, {
    AvatarStyle? avatar,
    required ProfileGender gender,
  }) async {
    _invalidate();
    await database.transaction((txn) async {
      await txn.update('memory_settings', {
        'nickname': name,
        'occupation': job,
        'gender': gender.name,
        'about': info,
      }, where: 'id = 1');
      await txn.update(
        'message_senders',
        {
          'name': name.isEmpty ? '你' : name,
          if (avatar != null) ...avatar.columns,
        },
        where: 'id = ?',
        whereArgs: ['user:local'],
      );
      await refreshGroupNoticeName(
        txn,
        'user:local',
        nickname.isEmpty ? '你' : nickname,
        name.isEmpty ? '你' : name,
      );
    });
    if (avatar != null) this.avatar = avatar;
    nickname = name;
    MessageSender.setLocalUserName(name);
    occupation = job;
    this.gender = gender;
    about = info;
    notifyListeners();
  }

  Future<void> saveEntry(
    String? id,
    String text, {
    required Map<String, Object?>? original,
  }) async {
    if (text.trim().isEmpty || text.length > memoryTextLimit)
      throw StateError('请填写不超过2000字的记忆');
    _invalidate();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _commitRecords((txn) async {
      if (id == null) {
        await txn.insert('user_memories', {
          'id': newMessageId(),
          'owner_id': ownerId,
          'memory_scope': scope,
          'text': text.trim(),
          ...memorySearchColumns(text.trim()),
          'manual': 1,
          'created_at': now,
          'updated_at': now,
        });
      } else {
        final changed = await txn.update(
          'user_memories',
          {
            'text': text.trim(),
            'manual': 1,
            'updated_at': now,
            'version': (original!['version'] as int) + 1,
            ...memorySearchColumns(text.trim()),
          },
          where: "id = ? AND owner_id = ? AND version = ? AND state = 'active'",
          whereArgs: [id, ownerId, original['version']],
        );
        if (changed == 0) throw StateError('这条记忆已被修改或删除，请重新打开后编辑');
      }
    });
  }

  Future<void> deleteEntry(String? id) async {
    _invalidate();
    await _commitRecords((txn) async {
      await _deleteMemory(txn, id);
    });
  }

  Future<void> _deleteMemory(Transaction txn, String? id) async {
    if (id == null) {
      await txn.delete(
        'user_memories',
        where: 'owner_id = ?',
        whereArgs: [ownerId],
      );
      await txn.rawUpdate(
        "UPDATE memory_jobs SET cursor = COALESCE((SELECT MAX(id) FROM memory_evidence WHERE run_id = memory_jobs.run_id), cursor), state = 'done' WHERE owner_id = ?",
        [ownerId],
      );
      return;
    }
    await txn.rawDelete(
      '''WITH RECURSIVE forgotten(id) AS (
      SELECT id FROM user_memories WHERE owner_id = ? AND id = ?
      UNION SELECT m.id FROM user_memories m INNER JOIN forgotten f ON m.superseded_by = f.id WHERE m.owner_id = ?)
      DELETE FROM user_memories WHERE id IN (SELECT id FROM forgotten)''',
      [ownerId, id, ownerId],
    );
  }

  Future<List<Map<String, Object?>>> _readRecords(DatabaseExecutor db) =>
      MemorySearch(db, ownerId, scope: scope).find(searchQuery, limit: 51);

  Future<List<Map<String, Object?>>> _commitRecords(
    Future<void> Function(Transaction txn) write,
  ) async {
    final next = await database.transaction((txn) async {
      await write(txn);
      return _readRecords(txn);
    });
    _setEntries(next);
    MemoryEvents.changed(ownerId);
    if (!_disposed) notifyListeners();
    return next;
  }

  Future<void> organizeTask(String runId) async {
    final worker = MemoryWorker(database, modelConfig, (error) {
      throw error;
    });
    final finished = Completer<void>();
    _taskOrganizers[runId] = worker;
    _taskOrganizationDone[runId] = finished;
    try {
      await worker.organize(runId);
    } finally {
      _taskOrganizers.remove(runId);
      _taskOrganizationDone.remove(runId);
      finished.complete();
    }
  }

  Future<void> cancelTaskOrganization(String runId) async {
    final finished = _taskOrganizationDone[runId];
    await _taskOrganizers[runId]?.cancel();
    await finished?.future;
  }

  Future<void> startConsolidation() async {
    _worker = MemoryWorker(database, modelConfig, (error) {
      if (!_disposed) {
        notices.value = null;
        notices.value = error.toString();
      }
    });
    await _worker!.start();
  }

  @override
  void dispose() {
    _disposed = true;
    _worker?.dispose();
    for (final worker in _taskOrganizers.values) {
      worker.dispose();
    }
    unawaited(_changes?.cancel());
    _invalidate();
    notices.dispose();
    super.dispose();
  }
}
