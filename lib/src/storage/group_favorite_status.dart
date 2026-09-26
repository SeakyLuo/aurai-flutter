import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';

typedef GroupMarkRecord = ({
  String groupId,
  String? actorId,
  String? actorName,
});

/// Batches visible message marks and their actors into at most two reads.
class GroupFavoriteStatus {
  static final _pending =
      Expando<Map<String, List<Completer<GroupMarkRecord?>>>>();

  static Future<GroupMarkRecord?> read(Database database, String messageId) {
    var requests = _pending[database];
    if (requests == null) {
      requests = {};
      _pending[database] = requests;
      scheduleMicrotask(() {
        final batch = _pending[database]!;
        _pending[database] = null;
        database
            .query(
              'group_favorite_messages',
              columns: ['message_id', 'conversation_id', 'marked_by'],
              where: 'message_id IN (SELECT value FROM json_each(?))',
              whereArgs: [jsonEncode(batch.keys.toList())],
            )
            .then((rows) async {
              final actorIds = rows
                  .map((row) => row['marked_by'])
                  .whereType<String>()
                  .toSet();
              final actors = actorIds.isEmpty
                  ? <Map<String, Object?>>[]
                  : await database.query(
                      'message_senders',
                      columns: ['id', 'name'],
                      where: 'id IN (SELECT value FROM json_each(?))',
                      whereArgs: [jsonEncode(actorIds.toList())],
                    );
              final names = {
                for (final actor in actors)
                  actor['id']: actor['name'] as String,
              };
              final saved = {
                for (final row in rows)
                  row['message_id']: (
                    groupId: row['conversation_id'] as String,
                    actorId: row['marked_by'] as String?,
                    actorName: names[row['marked_by']],
                  ),
              };
              for (final entry in batch.entries) {
                for (final waiter in entry.value) {
                  waiter.complete(saved[entry.key]);
                }
              }
            })
            .then<void>(
              (_) {},
              onError: (Object error, StackTrace stack) {
                for (final waiters in batch.values) {
                  for (final waiter in waiters) {
                    waiter.completeError(error, stack);
                  }
                }
              },
            );
      });
    }
    final result = Completer<GroupMarkRecord?>();
    requests.putIfAbsent(messageId, () => []).add(result);
    return result.future;
  }
}
