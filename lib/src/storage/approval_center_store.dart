import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../domain/message_sender.dart';
import '../html_games/miniapp_team_store.dart';

const approvalCenterSchema = [
  '''CREATE TABLE approval_requests (
    id TEXT PRIMARY KEY, kind TEXT NOT NULL, title TEXT NOT NULL,
    description TEXT NOT NULL, sender_name TEXT NOT NULL,
    app_id TEXT, sender_id TEXT, requested_at INTEGER NOT NULL,
    deadline INTEGER, allow_scopes INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'pending', resolved_at INTEGER,
    scope TEXT
  )''',
  'CREATE INDEX approval_requests_status_time ON approval_requests(status, requested_at DESC)',
];

class ApprovalCenterStore {
  ApprovalCenterStore(this.database);
  final Database database;
  static final changes = StreamController<void>.broadcast();
  static final prompts = StreamController<String>.broadcast();
  static final liveTools = <String, Future<void> Function(String)>{};

  static String teamKey(String app, String sender, int time) =>
      'team:$app:$sender:$time';

  static Future<void> insert(DatabaseExecutor db, Map<String, Object?> row) =>
      db.insert('approval_requests', row).then((_) {});

  static void announce(String id) {
    changes.add(null);
    prompts.add(id);
  }

  Future<Map<String, Object?>> read(String id) async => (await database.query(
    'approval_requests',
    where: 'id = ?',
    whereArgs: [id],
  )).single;

  Future<List<Map<String, Object?>>> page({
    required bool pending,
    int offset = 0,
  }) => database.query(
    'approval_requests',
    where: pending ? "status = 'pending'" : "status != 'pending'",
    orderBy: 'requested_at DESC, id',
    limit: 50,
    offset: offset,
  );

  static Future<void> finish(
    DatabaseExecutor db,
    String id,
    String status, {
    String? scope,
  }) async {
    await db.update(
      'approval_requests',
      {
        'status': status,
        'scope': scope,
        'resolved_at': DateTime.now().microsecondsSinceEpoch,
      },
      where: "id = ? AND status = 'pending'",
      whereArgs: [id],
    );
  }

  Future<void> decide(Map<String, Object?> row, String decision) async {
    final id = row['id'] as String;
    final current = await read(id);
    if (current['status'] != 'pending') throw StateError('此申请已处理');
    if (row['kind'] == 'miniapp') {
      await MiniappTeamStore(database).manage(
        row['app_id'] as String,
        MessageSender.localUser.id,
        decision == 'deny' ? 'reject' : 'approve',
        row['sender_id'] as String,
        requestedAt: row['requested_at'] as int,
      );
    } else {
      final handler = liveTools[id];
      if (handler == null) throw StateError('此任务已结束，不能继续授权');
      await handler(decision);
    }
    changes.add(null);
  }
}
