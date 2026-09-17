import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../domain/interactive_message.dart';

typedef CallbackCardUpdate = ({
  String conversationId,
  String messageId,
  InteractiveMessage card,
});

/// Status and its card presentation are written in the same transaction.
Future<List<CallbackCardUpdate>> transitionInteractiveCallbacks(
  DatabaseExecutor db,
  List<Map<String, Object?>> events,
  String status, {
  String? error,
}) async {
  final native = events.where((e) => e['actor_id'] != null).toList();
  if (native.isEmpty) return [];
  final ids = native.map((e) => e['message_id']).toSet().toList();
  final rows = await db.query(
    'messages',
    columns: ['id', 'conversation_id', 'interactive_json', 'kind'],
    where: 'id IN (${List.filled(ids.length, '?').join(',')})',
    whereArgs: ids,
  );
  final cards = {
    for (final row in rows)
      if (row['kind'] != 'system' && row['interactive_json'] != null)
        row['id'] as String:
            jsonDecode(row['interactive_json'] as String)
                as Map<String, dynamic>,
  };
  final changed = <String>{};
  final now = DateTime.now().microsecondsSinceEpoch;
  final batch = db.batch();
  for (final event in native) {
    final messageId = event['message_id'] as String;
    final json = cards[messageId];
    final participant =
        (json?['participants'] as Map?)?[event['actor_id']] as Map?;
    final callback = participant?['callback'] as Map?;
    final current =
        callback?['id'] == event['id'] &&
        participant?['revision'] == event['participant_revision'];
    final nextStatus = current ? status : 'expired';
    batch.update(
      'message_callbacks',
      {
        'status': nextStatus,
        if (nextStatus == 'expired') 'processed_at': now,
        if (nextStatus == 'failed') 'attempts': (event['attempts'] as int) + 1,
      },
      where: 'id = ? AND processed_at IS NULL',
      whereArgs: [event['id']],
    );
    if (!current) {
      if (callback?['id'] == event['id']) {
        participant!.remove('callback');
        changed.add(messageId);
      }
      continue;
    }
    participant!['callback'] = {
      'id': event['id'],
      'buttonId': callback?['buttonId'] ?? participant['buttonId'],
      'status': status,
      'updatedAt': now,
      if (error != null) 'error': error,
    };
    changed.add(messageId);
  }
  for (final id in changed) {
    batch.update(
      'messages',
      {'interactive_json': jsonEncode(cards[id])},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  await batch.commit(noResult: true);
  return [
    for (final row in rows)
      if (changed.contains(row['id']))
        (
          conversationId: row['conversation_id'] as String,
          messageId: row['id'] as String,
          card: InteractiveMessage.fromJson(cards[row['id']]!),
        ),
  ];
}
