import 'package:sqflite/sqflite.dart';
import 'miniapp_program.dart';

class MiniappReplyCapability {
  const MiniappReplyCapability();

  Future<({Map<String, Object?> before, Map<String, bool> changed})> apply(
    DatabaseExecutor db, {
    required String conversationId,
    required String messageId,
    required Set<String> agents,
    required Map<String, bool> states,
    required Map<String, Object?> before,
    required bool release,
  }) async {
    if (states.keys.any((id) => !agents.contains(id))) {
      throw ArgumentError('只能控制当前群聊中 AI 成员的接话');
    }
    if (states.isNotEmpty && before.isEmpty) {
      final controlling = await db.query(
        'app_state',
        columns: ['key'],
        where:
            "key LIKE 'miniapp-program:%' AND key != ? AND json_extract(value, '\$.conversationId') = ? AND EXISTS (SELECT 1 FROM json_each(json_extract(value, '\$.replyBefore')))",
        whereArgs: [MiniappProgram.key(messageId), conversationId],
        limit: 1,
      );
      if (controlling.isNotEmpty) {
        throw StateError('请先结束当前正在安排群聊发言的小程序');
      }
      final paused = await db.query(
        'group_participation',
        where: 'conversation_id = ?',
        whereArgs: [conversationId],
      );
      final bySender = {for (final row in paused) row['sender_id']: row};
      before = {for (final id in agents) id: bySender[id]};
    }
    if (release) {
      return (
        before: <String, Object?>{},
        changed: await restore(db, conversationId, before),
      );
    }
    final batch = db.batch();
    for (final entry in states.entries) {
      batch.insert('group_participation', {
        'conversation_id': conversationId,
        'sender_id': entry.key,
        'paused': entry.value ? 0 : 1,
        'reason': entry.value ? null : '小程序正在安排发言',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    return (before: before, changed: states);
  }

  Future<Map<String, bool>> restore(
    DatabaseExecutor db,
    String conversationId,
    Map<String, Object?> before,
  ) async {
    final changed = <String, bool>{};
    final batch = db.batch();
    for (final entry in before.entries) {
      final old = entry.value as Map?;
      batch.insert('group_participation', {
        'conversation_id': conversationId,
        'sender_id': entry.key,
        'paused': old?['paused'] ?? 0,
        'reason': old?['reason'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      changed[entry.key] = old?['paused'] != 1;
    }
    await batch.commit(noResult: true);
    return changed;
  }
}
