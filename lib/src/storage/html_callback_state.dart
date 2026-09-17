import 'dart:async';

import 'package:sqflite/sqflite.dart';

/// HTML callbacks reuse the queue, but require an explicit result receipt.
abstract final class HtmlCallbackState {
  static final changes = StreamController<String>.broadcast();

  static bool owns(Map<String, Object?> event) =>
      event['actor_id'] == null && event['status'] != 'legacy';

  static Future<void> transition(DatabaseExecutor db,
      List<Map<String, Object?>> events, String status) async {
    final ids = events.where(owns).map((e) => e['id']).toList();
    if (ids.isEmpty) return;
    final slots = List.filled(ids.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE message_callbacks SET status = ?'
      '${status == 'failed' ? ', attempts = attempts + 1' : ''}'
      ' WHERE id IN ($slots) AND processed_at IS NULL',
      [status, ...ids],
    );
  }

  static void notify(List<Map<String, Object?>> events) {
    for (final id in events.where(owns).map((e) => e['message_id'] as String).toSet()) {
      changes.add(id);
    }
  }

  static Future<List<Map<String, Object?>>> read(
      DatabaseExecutor db, String messageId, {String? eventId}) => db.query(
    'message_callbacks',
    columns: ['id AS eventId', 'status', 'attempts', 'created_at AS createdAt'],
    where: "message_id = ? AND actor_id IS NULL AND status != 'legacy'"
        '${eventId == null ? '' : ' AND id = ?'}',
    whereArgs: [messageId, if (eventId != null) eventId],
    orderBy: 'created_at DESC, id DESC',
    limit: eventId == null ? 20 : 1,
  );

  static Future<Map<String, Object?>> requireEvent(DatabaseExecutor db,
      String messageId, String eventId, String senderId) async {
    final rows = await db.query('message_callbacks',
      where: "id = ? AND message_id = ? AND sender_id = ? AND actor_id IS NULL AND status != 'legacy'",
      whereArgs: [eventId, messageId, senderId], limit: 1);
    if (rows.isEmpty) throw StateError('这次 HTML 操作已不存在');
    return rows.single;
  }

  static Future<void> complete(DatabaseExecutor db, String eventId) async {
    await db.update('message_callbacks', {
      'status': 'completed',
      'processed_at': DateTime.now().microsecondsSinceEpoch,
    }, where: 'id = ? AND processed_at IS NULL', whereArgs: [eventId]);
  }

  static Future<void> retry(Database db, String messageId, String eventId) async {
    await db.transaction((txn) async {
      final refs = await txn.query('html_games', columns: ['creator_id', 'conversation_id'],
        where: "message_id = ? AND message_id IN (SELECT id FROM messages WHERE kind = 'html_game')",
        whereArgs: [messageId], limit: 1);
      if (refs.isEmpty) throw StateError('小应用入口已删除或撤回');
      final ref = refs.single;
      final event = await requireEvent(txn, messageId, eventId, ref['creator_id'] as String);
      if (event['status'] != 'failed') throw StateError('只有失败或中断的操作可以重试');
      final destinations = await txn.rawQuery(
        "SELECT id FROM conversations WHERE id = ? AND archived = 0 AND ((kind = 'direct' AND default_sender_id = ?) OR (kind = 'group' AND EXISTS (SELECT 1 FROM conversation_members WHERE conversation_id = conversations.id AND sender_id = ? AND left_at IS NULL))) LIMIT 1",
        [ref['conversation_id'], ref['creator_id'], ref['creator_id']]);
      if (destinations.isEmpty) throw StateError('创建者已离开或会话已归档，暂时无法重试');
      await transition(txn, [event], 'queued');
    });
    changes.add(messageId);
  }
}
