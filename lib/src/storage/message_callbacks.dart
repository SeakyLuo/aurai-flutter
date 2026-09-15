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
 attempts INTEGER NOT NULL DEFAULT 0
)''';

const messageCallbackIndex =
    'CREATE INDEX message_callbacks_pending ON message_callbacks(created_at, id) WHERE processed_at IS NULL AND attempts < 3';

class MessageCallbacks {
  MessageCallbacks(this.database);
  final Database database;
  static final changes = StreamController<void>.broadcast();

  static Future<void> enqueue(
    DatabaseExecutor db, {
    required String id,
    required String messageId,
    required String conversationId,
    required String senderId,
    required Map<String, Object?> payload,
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
      'created_at': DateTime.now().microsecondsSinceEpoch,
    });
  }

  Future<List<Map<String, Object?>>> pending(
    String conversationId,
    String senderId,
  ) => database.query(
    'message_callbacks',
    where:
        'conversation_id = ? AND sender_id = ? AND processed_at IS NULL AND attempts < 3',
    whereArgs: [conversationId, senderId],
    orderBy: 'created_at, id',
    limit: 20,
  );

  Future<void> finish(List<Map<String, Object?>> events, bool success) async {
    if (events.isEmpty) return;
    final slots = List.filled(events.length, '?').join(',');
    final ids = events.map((e) => e['id']).toList();
    await database.rawUpdate(
      success
          ? 'UPDATE message_callbacks SET processed_at = ? WHERE id IN ($slots)'
          : 'UPDATE message_callbacks SET attempts = attempts + 1 WHERE id IN ($slots)',
      [if (success) DateTime.now().microsecondsSinceEpoch, ...ids],
    );
  }
}
