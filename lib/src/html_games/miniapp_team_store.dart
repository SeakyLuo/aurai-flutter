import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../domain/message_sender.dart';
import '../storage/approval_center_store.dart';

/// Source collaboration does not grant access to saved or session data.
class MiniappTeamStore {
  MiniappTeamStore(this.database);
  final Database database;
  static final changes = StreamController<String>.broadcast();
  static const pageSize = 50;

  Future<Map<String, Map<String, Object?>>> access(
    List<String> ids,
    String actor,
  ) async {
    if (ids.isEmpty) return {};
    final args = List.filled(ids.length, '?').join(',');
    final results = await Future.wait([
      database.query(
        'html_apps',
        columns: ['id', 'creator_id'],
        where: 'id IN ($args)',
        whereArgs: ids,
      ),
      database.query(
        'miniapp_developers',
        columns: ['app_id'],
        where: 'sender_id = ? AND app_id IN ($args)',
        whereArgs: [actor, ...ids],
      ),
    ]);
    final teams = results[1].map((row) => row['app_id']).toSet();
    return {
      for (final row in results[0])
        row['id'] as String: {
          'canEdit': canManage(row, actor) || teams.contains(row['id']),
          'canManageTeam': canManage(row, actor),
        },
    };
  }

  // Installed library copies share their original application's development
  // team, including bundled apps available in the local library.
  static Future<Map<String, Object?>> app(
    DatabaseExecutor db,
    String id,
  ) async {
    final rows = await db.query(
      'html_apps',
      where: '''id = COALESCE((SELECT source_id FROM miniapp_installations
        WHERE app_id = ?), ?)''',
      whereArgs: [id, id],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('小程序源码不存在');
    return rows.single;
  }

  static bool canManage(Map<String, Object?> app, String actor) =>
      actor == MessageSender.localUser.id || app['creator_id'] == actor;

  static Future<bool> canEdit(
    DatabaseExecutor db,
    Map<String, Object?> app,
    String actor,
  ) async {
    if (canManage(app, actor)) return true;
    return (await db.query(
      'miniapp_developers',
      columns: ['sender_id'],
      where: 'app_id = ? AND sender_id = ?',
      whereArgs: [app['id'], actor],
      limit: 1,
    )).isNotEmpty;
  }

  Future<Map<String, Object?>> read(
    String id,
    String actor, {
    bool requests = false,
    int offset = 0,
  }) async {
    final source = await app(database, id);
    final appId = source['id'] as String;
    final manager = canManage(source, actor);
    if (requests && !manager) throw StateError('只有创建人可以查看全部修改申请');
    final results = await Future.wait([
      database.query(
        requests ? 'miniapp_edit_requests' : 'miniapp_developers',
        where: 'app_id = ?${requests ? " AND status = 'pending'" : ''}',
        whereArgs: [appId],
        orderBy: '${requests ? 'requested_at' : 'added_at'} DESC, sender_id',
        limit: pageSize + 1,
        offset: offset,
      ),
      database.query(
        'miniapp_edit_requests',
        where: 'app_id = ? AND sender_id = ?',
        whereArgs: [appId, actor],
      ),
      database.rawQuery(
        "SELECT COUNT(*) AS count FROM miniapp_edit_requests WHERE app_id = ? AND status = 'pending'",
        [appId],
      ),
    ]);
    final rows = results[0].take(pageSize).toList();
    final ids = {
      source['creator_id'] as String,
      ...rows.map((r) => r['sender_id'] as String),
    };
    final profiles = await database.query(
      'message_senders',
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids.toList(),
    );
    final byId = {for (final row in profiles) row['id']: row};
    return {
      'appId': appId,
      'title': source['title'],
      'creator': byId[source['creator_id']]!,
      'canManage': manager,
      'canEdit': await canEdit(database, source, actor),
      'ownRequest': results[1].firstOrNull,
      if (manager) 'pendingCount': results[2].single['count'],
      'entries': [
        for (final row in rows) {...row, 'profile': byId[row['sender_id']]!},
      ],
      'hasMore': results[0].length > pageSize,
    };
  }

  Future<Map<String, Object?>> request(
    String id,
    String actor,
    String reason,
  ) async {
    if (reason.trim().isEmpty || reason.length > 1000)
      throw ArgumentError('申请原因需为 1–1000 字');
    final result = await database.transaction((txn) async {
      final source = await app(txn, id);
      final appId = source['id'] as String;
      final base = {'appId': appId, 'title': source['title']};
      if (await canEdit(txn, source, actor))
        return {...base, 'status': 'member'};
      await _requireMember(txn, actor);
      final current = await txn.query(
        'miniapp_edit_requests',
        where: 'app_id = ? AND sender_id = ?',
        whereArgs: [appId, actor],
      );
      if (current.isNotEmpty && current.single['status'] == 'pending') {
        return {
          ...base,
          'status': 'pending',
          'requestedAt': current.single['requested_at'],
        };
      }
      final now = DateTime.now().microsecondsSinceEpoch;
      await txn.insert('miniapp_edit_requests', {
        'app_id': appId,
        'sender_id': actor,
        'reason': reason,
        'status': 'pending',
        'requested_at': now,
        'reviewed_by': null,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      final sender = (await txn.query(
        'message_senders',
        columns: ['name'],
        where: 'id = ?',
        whereArgs: [actor],
      )).single;
      await ApprovalCenterStore.insert(txn, {
        'id': ApprovalCenterStore.teamKey(appId, actor, now),
        'kind': 'miniapp',
        'title': '申请加入 ${source['title']} 的开发团队',
        'description': reason,
        'sender_name': sender['name'],
        'app_id': appId,
        'sender_id': actor,
        'requested_at': now,
      });
      return {...base, 'status': 'pending', 'requestedAt': now};
    });
    changes.add(result['appId'] as String);
    if (result['status'] == 'pending') {
      ApprovalCenterStore.announce(
        ApprovalCenterStore.teamKey(
          result['appId'] as String,
          actor,
          result['requestedAt'] as int,
        ),
      );
    }
    return result;
  }

  Future<Map<String, Object?>> manage(
    String id,
    String actor,
    String action,
    String member, {
    int? requestedAt,
  }) async {
    final result = await database.transaction((txn) async {
      final source = await app(txn, id);
      final appId = source['id'] as String;
      final cancelling = action == 'cancel';
      if (cancelling ? member != actor : !canManage(source, actor)) {
        throw StateError('只有创建人可以管理开发团队；申请人只能撤销自己的申请');
      }
      if (source['creator_id'] == member)
        throw StateError('创建人已拥有编辑权限，不能移出开发团队');
      if (!['approve', 'reject', 'add', 'remove', 'cancel'].contains(action))
        throw ArgumentError('未知的团队操作');
      if (['approve', 'reject', 'cancel'].contains(action)) {
        final pending = await txn.query(
          'miniapp_edit_requests',
          where: 'app_id = ? AND sender_id = ?',
          whereArgs: [appId, member],
        );
        if (pending.isEmpty ||
            pending.single['status'] != 'pending' ||
            pending.single['requested_at'] != requestedAt) {
          throw StateError('申请状态已变化，请重新查看');
        }
      }
      if (action == 'approve' || action == 'add') {
        await _requireMember(txn, member);
        await txn.insert('miniapp_developers', {
          'app_id': appId,
          'sender_id': member,
          'added_at': DateTime.now().microsecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      } else if (action == 'remove') {
        await txn.delete(
          'miniapp_developers',
          where: 'app_id = ? AND sender_id = ?',
          whereArgs: [appId, member],
        );
      }
      if (action != 'remove') {
        final pendingApprovals = await txn.query(
          'approval_requests',
          columns: ['id'],
          where:
              "kind = 'miniapp' AND app_id = ? AND sender_id = ? AND status = 'pending'",
          whereArgs: [appId, member],
          limit: 1,
        );
        if (pendingApprovals.isNotEmpty) {
          await ApprovalCenterStore.finish(
            txn,
            pendingApprovals.single['id'] as String,
            cancelling
                ? 'cancelled'
                : action == 'reject'
                ? 'denied'
                : 'approved',
          );
        }
        await txn.update(
          'miniapp_edit_requests',
          {
            'status': cancelling
                ? 'cancelled'
                : action == 'reject'
                ? 'rejected'
                : 'approved',
            'reviewed_by': actor,
          },
          where: "app_id = ? AND sender_id = ? AND status = 'pending'",
          whereArgs: [appId, member],
        );
      }
      return {
        'appId': appId,
        'title': source['title'],
        'action': action,
        'memberId': member,
      };
    });
    changes.add(result['appId'] as String);
    ApprovalCenterStore.changes.add(null);
    return result;
  }

  Future<void> addMembers(String id, String actor, Set<String> members) async {
    if (members.isEmpty) throw ArgumentError('请选择开发成员');
    final appId = await database.transaction((txn) async {
      final source = await app(txn, id);
      if (!canManage(source, actor)) throw StateError('只有创建人可以管理开发团队');
      if (members.contains(source['creator_id']))
        throw StateError('创建人已拥有编辑权限');
      final placeholders = List.filled(members.length, '?').join(',');
      final rows = await txn.query(
        'message_senders',
        columns: ['id'],
        where: "id IN ($placeholders) AND kind = 'agent' AND archived = 0",
        whereArgs: members.toList(),
      );
      if (rows.length != members.length) throw StateError('所选联系人不存在或已归档');
      final appId = source['id'] as String;
      final now = DateTime.now().microsecondsSinceEpoch;
      final batch = txn.batch();
      for (final member in members) {
        batch.insert('miniapp_developers', {
          'app_id': appId,
          'sender_id': member,
          'added_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        batch.update(
          'miniapp_edit_requests',
          {'status': 'approved', 'reviewed_by': actor},
          where: "app_id = ? AND sender_id = ? AND status = 'pending'",
          whereArgs: [appId, member],
        );
      }
      await batch.commit(noResult: true);
      await txn.update(
        'approval_requests',
        {'status': 'approved', 'resolved_at': now},
        where:
            "kind = 'miniapp' AND app_id = ? AND sender_id IN ($placeholders) AND status = 'pending'",
        whereArgs: [appId, ...members],
      );
      return appId;
    });
    changes.add(appId);
    ApprovalCenterStore.changes.add(null);
  }

  static Future<void> _requireMember(DatabaseExecutor db, String id) async {
    final rows = await db.query(
      'message_senders',
      columns: ['id'],
      where: "id = ? AND kind = 'agent' AND archived = 0",
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('该联系人不存在或已归档');
  }

  Future<List<MessageSender>> candidates(
    String appId, {
    int offset = 0,
    String query = '',
  }) async {
    final rows = await database.query(
      'message_senders',
      where:
          '''kind = 'agent' AND archived = 0 AND instr(lower(name), lower(?)) > 0
        AND id != (SELECT creator_id FROM html_apps WHERE id = ?)
        AND id NOT IN (SELECT sender_id FROM miniapp_developers WHERE app_id = ?)''',
      whereArgs: [query, appId, appId],
      orderBy: 'name, id',
      limit: pageSize,
      offset: offset,
    );
    return rows.map(MessageSender.fromRow).toList();
  }

  Future<List<Map<String, Object?>>> pending(
    String actor, {
    int offset = 0,
    String? appId,
  }) async {
    final rows = await database.query(
      'miniapp_edit_requests',
      where:
          "status = 'pending'${appId == null ? '' : ' AND app_id = ?'}${actor == MessageSender.localUser.id ? '' : ' AND (sender_id = ? OR app_id IN (SELECT id FROM html_apps WHERE creator_id = ?))'}",
      whereArgs: [
        if (appId != null) appId,
        if (actor != MessageSender.localUser.id) ...[actor, actor],
      ],
      orderBy: 'requested_at DESC, app_id, sender_id',
      limit: pageSize,
      offset: offset,
    );
    if (rows.isEmpty) return [];
    final ids = rows.map((r) => r['app_id'] as String).toSet().toList();
    final senders = rows.map((r) => r['sender_id'] as String).toSet().toList();
    final results = await Future.wait([
      database.query(
        'html_apps',
        columns: ['id', 'title', 'creator_id'],
        where: 'id IN (${List.filled(ids.length, '?').join(',')})',
        whereArgs: ids,
      ),
      database.query(
        'message_senders',
        columns: ['id', 'name'],
        where: 'id IN (${List.filled(senders.length, '?').join(',')})',
        whereArgs: senders,
      ),
    ]);
    final apps = {for (final r in results[0]) r['id']: r};
    final names = {for (final r in results[1]) r['id']: r['name']};
    return [
      for (final row in rows)
        {
          'appId': row['app_id'],
          'title': apps[row['app_id']]!['title'],
          'senderId': row['sender_id'],
          'name': names[row['sender_id']],
          'reason': row['reason'],
          'requestedAt': row['requested_at'],
          'canReview': canManage(apps[row['app_id']]!, actor),
        },
    ];
  }
}
