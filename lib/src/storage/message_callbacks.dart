import 'html_callback_state.dart';
import 'interactive_callback_state.dart';
import '../domain/interactive_message.dart';
import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';

const messageCallbackSchema = '''CREATE TABLE message_callbacks (
 id TEXT PRIMARY KEY,
 message_id TEXT NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
 conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
 sender_id TEXT NOT NULL,
 payload_json TEXT NOT NULL,
 created_at INTEGER NOT NULL,
 processed_at INTEGER,
 actor_id TEXT,
 participant_revision INTEGER,
 status TEXT NOT NULL DEFAULT 'legacy',
 attempts INTEGER NOT NULL DEFAULT 0
)''';

const messageCallbackIndex =
    "CREATE INDEX message_callbacks_pending ON message_callbacks(created_at, id) WHERE processed_at IS NULL AND ((status = 'legacy' AND attempts < 3) OR status = 'queued')";

class MessageCallbacks {
  MessageCallbacks(this.database);
  final Database database;
  static final changes = StreamController<void>.broadcast();
  static final cardChanges =
      StreamController<List<CallbackCardUpdate>>.broadcast();

  static Future<void> enqueue(
    DatabaseExecutor db, {
    required String id,
    required String messageId,
    required String conversationId,
    required String senderId,
    required Map<String, Object?> payload,
    String? actorId,
    int? participantRevision,
    bool html = false,
  }) async {
    final encoded = jsonEncode(payload);
    if (utf8.encode(encoded).length > 16384)
      throw ArgumentError('操作回调最多 16 KB');
    final existing = await db.query(
      'message_callbacks',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      if (existing.single['message_id'] != messageId ||
          existing.single['payload_json'] != encoded) {
        throw StateError('操作编号已用于其他操作');
      }
      if (html && existing.single['status'] == 'legacy') {
        // Older HTML callbacks had no receipt. Do not replay an uncertain result.
        await db.update('message_callbacks', {
          'status': existing.single['processed_at'] == null ? 'failed' : 'completed',
        }, where: 'id = ?', whereArgs: [id]);
      }
      return;
    }
    final destinations = await db.rawQuery(
      "SELECT id FROM conversations WHERE id = ? AND archived = 0 AND ((kind = 'direct' AND default_sender_id = ?) OR (kind = 'group' AND EXISTS (SELECT 1 FROM conversation_members WHERE conversation_id = conversations.id AND sender_id = ? AND left_at IS NULL))) LIMIT 1",
      [conversationId, senderId, senderId],
    );
    if (destinations.isEmpty) throw StateError('消息创建者已不在会话中或会话已归档');
    await db.insert('message_callbacks', {
      'id': id,
      'message_id': messageId,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'payload_json': encoded,
      if (html) 'status': 'queued',
      if (actorId != null) ...{
        'actor_id': actorId,
        'participant_revision': participantRevision,
        'status': 'queued',
      },
      'created_at': DateTime.now().microsecondsSinceEpoch,
    });
  }

  static const readyWhere =
      "processed_at IS NULL AND ((status = 'legacy' AND attempts < 3) OR status = 'queued')";

  Future<List<Map<String, Object?>>> pending(
    String conversationId,
    String senderId,
  ) async {
    final result = await database.transaction((txn) async {
      final events = await txn.query(
        'message_callbacks',
        where: 'conversation_id = ? AND sender_id = ? AND $readyWhere',
        whereArgs: [conversationId, senderId],
        orderBy: 'created_at, id',
        limit: 20,
      );
      await HtmlCallbackState.transition(txn, events, 'processing');
      final updates = await transitionInteractiveCallbacks(
        txn,
        events,
        'processing',
      );
      final valid = updates
          .expand((u) => u.card.participants.values)
          .map((p) => (p['callback'] as Map?)?['id'])
          .toSet();
      return (
        events: events
            .where((e) => e['actor_id'] == null || valid.contains(e['id']))
            .toList(),
        updates: updates,
      );
    });
    cardChanges.add(result.updates);
    HtmlCallbackState.notify(result.events);
    return result.events;
  }

  Future<void> finish(
    List<Map<String, Object?>> events,
    bool success, {
    String? error,
  }) async {
    if (events.isEmpty) return;
    final updates = await database.transaction((txn) async {
      final ids = events.map((e) => e['id']).toList();
      final slots = List.filled(ids.length, '?').join(',');
      final remaining = await txn.query(
        'message_callbacks',
        where:
            "id IN ($slots) AND processed_at IS NULL AND status IN ('legacy','queued','processing')",
        whereArgs: ids,
      );
      final legacy = remaining
          .where((e) => e['actor_id'] == null && e['status'] == 'legacy')
          .map((e) => e['id'])
          .toList();
      if (legacy.isNotEmpty) {
        final legacySlots = List.filled(legacy.length, '?').join(',');
        await txn.rawUpdate(
          success
              ? 'UPDATE message_callbacks SET processed_at = ? WHERE id IN ($legacySlots)'
              : 'UPDATE message_callbacks SET attempts = attempts + 1 WHERE id IN ($legacySlots)',
          [if (success) DateTime.now().microsecondsSinceEpoch, ...legacy],
        );
      }
      await HtmlCallbackState.transition(txn, remaining, 'failed');
      return transitionInteractiveCallbacks(
        txn,
        remaining,
        'failed',
        error: error ?? (success ? 'AI 尚未把处理结果写回卡片' : 'AI 处理未完成，请重试'),
      );
    });
    cardChanges.add(updates);
    HtmlCallbackState.notify(events);
  }

  Future<void> recoverInterrupted() async {
    final updates = await database.transaction((txn) async {
      final events = await txn.query(
        'message_callbacks',
        where: "status = 'processing' AND processed_at IS NULL",
      );
      await HtmlCallbackState.transition(txn, events, 'failed');
      return transitionInteractiveCallbacks(
        txn,
        events,
        'failed',
        error: '上次处理已中断，可重试',
      );
    });
    cardChanges.add(updates);
  }

  Future<InteractiveMessage> retry(
    String messageId,
    String eventId,
    String actorId,
  ) async {
    final result = await database.transaction((txn) async {
      final events = await txn.query(
        'message_callbacks',
        where: 'id = ? AND message_id = ? AND actor_id = ?',
        whereArgs: [eventId, messageId, actorId],
        limit: 1,
      );
      if (events.isEmpty) throw StateError('这次操作已不存在');
      final event = events.single;
      if (event['status'] != 'failed') throw StateError('操作状态已变化，请查看当前卡片');
      final destinations = await txn.rawQuery(
        "SELECT id FROM conversations WHERE id = ? AND archived = 0 AND ((kind = 'direct' AND default_sender_id = ?) OR (kind = 'group' AND EXISTS (SELECT 1 FROM conversation_members WHERE conversation_id = conversations.id AND sender_id = ? AND left_at IS NULL))) LIMIT 1",
        [event['conversation_id'], event['sender_id'], event['sender_id']],
      );
      if (destinations.isEmpty) throw StateError('创建者已不在会话中或会话已归档');
      final updates = await transitionInteractiveCallbacks(
        txn,
        events,
        'queued',
      );
      return updates;
    });
    cardChanges.add(result);
    if (result.isEmpty) throw StateError('原交互已更新，这次操作不再重试');
    changes.add(null);
    return result.single.card;
  }
}
