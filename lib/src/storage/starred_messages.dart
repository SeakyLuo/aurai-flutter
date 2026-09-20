import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';

const starredMessagesSchema = '''CREATE TABLE starred_messages (
  owner_id TEXT NOT NULL,
  message_id TEXT NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  starred_at INTEGER NOT NULL,
  PRIMARY KEY (owner_id, message_id)
)''';
const starredMessagesIndex =
    'CREATE INDEX starred_messages_time ON starred_messages(owner_id, starred_at DESC, message_id DESC)';

class StarredMessages {
  StarredMessages(this.database, {this.ownerId = 'user:local'});
  static final changes =
      StreamController<
        ({String owner, String message, bool starred})
      >.broadcast();
  static final _pending = Expando<Map<String, List<Completer<bool>>>>();

  Future<bool> containsBatched(String messageId) {
    var batch = _pending[database];
    if (batch == null) {
      batch = {};
      _pending[database] = batch;
      scheduleMicrotask(() async {
        final requests = _pending[database]!;
        _pending[database] = null;
        try {
          final rows = await database.rawQuery(
            "SELECT message_id FROM starred_messages WHERE owner_id = 'user:local' AND message_id IN (SELECT value FROM json_each(?))",
            [jsonEncode(requests.keys.toList())],
          );
          final ids = rows.map((row) => row['message_id']).toSet();
          for (final entry in requests.entries) {
            for (final waiter in entry.value) {
              waiter.complete(ids.contains(entry.key));
            }
          }
        } on Object catch (error, stack) {
          for (final waiters in requests.values) {
            for (final waiter in waiters) {
              waiter.completeError(error, stack);
            }
          }
        }
      });
    }
    final result = Completer<bool>();
    batch.putIfAbsent(messageId, () => []).add(result);
    return result.future;
  }

  final String ownerId;
  final Database database;

  Future<bool> contains(String messageId) async => (await database.query(
    'starred_messages',
    columns: ['message_id'],
    where: 'owner_id = ? AND message_id = ?',
    whereArgs: [ownerId, messageId],
    limit: 1,
  )).isNotEmpty;

  Future<void> set(String messageId, bool starred, {int? starredAt}) async {
    if (starred) {
      await database.insert('starred_messages', {
        'owner_id': ownerId,
        'message_id': messageId,
        'starred_at': starredAt ?? DateTime.now().microsecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      await database.delete(
        'starred_messages',
        where: 'owner_id = ? AND message_id = ?',
        whereArgs: [ownerId, messageId],
      );
    }
    changes.add((owner: ownerId, message: messageId, starred: starred));
  }

  Future<int?> removeForUndo(String messageId) async {
    final timestamp = await database.transaction((txn) async {
      final rows = await txn.query(
        'starred_messages',
        columns: ['starred_at'],
        where: 'owner_id = ? AND message_id = ?',
        whereArgs: [ownerId, messageId],
      );
      if (rows.isEmpty) return null;
      await txn.delete(
        'starred_messages',
        where: 'owner_id = ? AND message_id = ?',
        whereArgs: [ownerId, messageId],
      );
      return rows.single['starred_at'] as int;
    });
    if (timestamp != null)
      changes.add((owner: ownerId, message: messageId, starred: false));
    return timestamp;
  }

  Future<List<Map<String, Object?>>> page({
    required int offset,
    String? viewerId,
  }) async {
    final stars = await database.query(
      'starred_messages',
      where: '''owner_id = ? AND EXISTS (SELECT 1 FROM messages
        WHERE messages.id = starred_messages.message_id
        AND (interactive_json IS NULL
          OR json_extract(interactive_json, '\$.participation.audience') IS NULL
          OR EXISTS (SELECT 1 FROM json_each(interactive_json, '\$.participation.audience')
            WHERE value = ?)))
        ${viewerId == null ? '' : "AND EXISTS (SELECT 1 FROM messages WHERE messages.id = starred_messages.message_id AND conversation_id IN (SELECT conversation_id FROM conversation_members WHERE sender_id = ? AND left_at IS NULL) AND (interactive_json IS NULL OR json_extract(interactive_json, '\$.participation.audience') IS NULL OR EXISTS (SELECT 1 FROM json_each(interactive_json, '\$.participation.audience') WHERE value = ?)))"}''',
      whereArgs: [
        ownerId,
        ownerId,
        if (viewerId != null) ...[viewerId, viewerId],
      ],
      orderBy: 'starred_at DESC, message_id DESC',
      limit: 50,
      offset: offset,
    );
    if (stars.isEmpty) return [];
    final messages = await database.query(
      'messages',
      columns: [
        'id',
        'conversation_id',
        'sender_id',
        'role',
        'text',
        'created_at',
        'interactive_json',
        'kind',
      ],
      where: 'id IN (${List.filled(stars.length, '?').join(',')})',
      whereArgs: stars.map((row) => row['message_id']).toList(),
    );
    final byId = {for (final message in messages) message['id']: message};
    return [
      for (final star in stars) {...byId[star['message_id']]!, ...star},
    ];
  }
}
