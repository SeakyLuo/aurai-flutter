import 'group_mute_schema.dart';
import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'group_sleep_store.dart';

const groupParticipationSchema = '''
CREATE TABLE group_participation (
  conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id TEXT NOT NULL REFERENCES message_senders(id) ON DELETE CASCADE,
  paused INTEGER NOT NULL DEFAULT 0,
  reason TEXT,
  PRIMARY KEY (conversation_id, sender_id)
)
''';

class GroupParticipation {
  GroupParticipation(this.database);
  final Database database;
  static final changes = StreamController<String>.broadcast();

  Future<Set<String>> paused(String groupId) async {
    final rows = await database.query(
      'group_participation',
      columns: ['sender_id'],
      where: 'conversation_id = ? AND paused = 1',
      whereArgs: [groupId],
    );
    return rows.map((row) => row['sender_id'] as String).toSet();
  }

  Future<Map<String, String>> pausedWithReasons(String groupId) async {
    final rows = await database.query(
      'group_participation',
      columns: ['sender_id', 'reason'],
      where: 'conversation_id = ? AND paused = 1',
      whereArgs: [groupId],
    );
    return {
      for (final row in rows)
        row['sender_id'] as String: row['reason'] as String,
    };
  }

  Future<Set<String>> pauseAll(String groupId) async {
    final ids = await database.transaction((txn) async {
      final rows = await txn.query(
        'conversation_members',
        columns: ['sender_id'],
        where:
            'conversation_id = ? AND left_at IS NULL AND sender_id IN '
            '(SELECT id FROM message_senders WHERE kind = ?)',
        whereArgs: [groupId, 'agent'],
      );
      final ids = rows.map((row) => row['sender_id'] as String).toSet();
      if (ids.isEmpty) return ids;
      final batch = txn.batch();
      for (final id in ids) {
        batch.insert('group_participation', {
          'conversation_id': groupId,
          'sender_id': id,
          'paused': 1,
          'reason': '用户暂停了全部成员的自动接话',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
      await GroupSleepStore.removeMembersIn(txn, groupId, ids);
      return ids;
    });
    if (ids.isNotEmpty) changes.add(groupId);
    return ids;
  }

  Future<Set<String>> resumeAll(String groupId) async {
    final ids = await database.transaction((txn) async {
      final rows = await txn.query(
        'group_participation',
        columns: ['sender_id'],
        where:
            'conversation_id = ? AND paused = 1 AND sender_id IN '
            '(SELECT sender_id FROM conversation_members WHERE conversation_id = ? AND left_at IS NULL AND ${effectiveGroupMuteSql('conversation_members')} != -1 AND ${effectiveGroupMuteSql('conversation_members')} <= ?) '
            'AND sender_id IN (SELECT id FROM message_senders WHERE kind = ?)',
        whereArgs: [
          groupId,
          groupId,
          DateTime.now().microsecondsSinceEpoch,
          'agent',
        ],
      );
      final ids = rows.map((row) => row['sender_id'] as String).toSet();
      if (ids.isNotEmpty) {
        await txn.update(
          'group_participation',
          {'paused': 0, 'reason': null},
          where:
              'conversation_id = ? AND sender_id IN (${List.filled(ids.length, '?').join(',')})',
          whereArgs: [groupId, ...ids],
        );
      }
      return ids;
    });
    if (ids.isNotEmpty) changes.add(groupId);
    return ids;
  }

  Future<void> setMembers(
    String groupId,
    Set<String> ids,
    bool paused, {
    String? reason,
  }) async {
    await database.transaction((txn) async {
      final batch = txn.batch();
      for (final id in ids) {
        batch.insert('group_participation', {
          'conversation_id': groupId,
          'sender_id': id,
          'paused': paused ? 1 : 0,
          'reason': paused ? reason : null,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
      if (paused) await GroupSleepStore.removeMembersIn(txn, groupId, ids);
    });
    changes.add(groupId);
  }

  Future<void> set(
    String groupId,
    String senderId,
    bool paused, {
    String? reason,
  }) async {
    await database.transaction(
      (txn) => setIn(txn, groupId, senderId, paused, reason: reason),
    );
    changes.add(groupId);
  }

  static Future<void> setIn(
    DatabaseExecutor txn,
    String groupId,
    String senderId,
    bool paused, {
    String? reason,
  }) async {
    final members = await txn.query(
      'conversation_members',
      columns: [
        'sender_id',
        '${effectiveGroupMuteSql('conversation_members')} AS muted_until',
      ],
      where: 'conversation_id = ? AND sender_id = ? AND left_at IS NULL',
      whereArgs: [groupId, senderId],
      limit: 1,
    );
    if (members.isEmpty) throw StateError('你已不在这个群聊中');
    if (members.single['muted_until'] == -1 ||
        (members.single['muted_until'] as int) >
            DateTime.now().microsecondsSinceEpoch) {
      throw StateError('该成员已被禁言，请先解除禁言再调整自动接话');
    }
    if (paused) await GroupSleepStore.removeIn(txn, groupId, senderId);
    await txn.insert('group_participation', {
      'conversation_id': groupId,
      'sender_id': senderId,
      'paused': paused ? 1 : 0,
      'reason': paused ? reason : null,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
