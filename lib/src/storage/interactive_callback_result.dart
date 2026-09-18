import 'interactive_callback_state.dart';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../domain/interactive_message.dart';

/// The event acknowledgement and its participant's result commit together.
Future<({InteractiveMessage card, bool applied, String status})>
completeInteractiveCallback(
  Database database, {
  required String messageId,
  required String senderId,
  required String eventId,
  required Map<String, Object?> result,
}) => database.transaction((txn) async {
  final events = await txn.query(
    'message_callbacks',
    where:
        'id = ? AND message_id = ? AND sender_id = ? AND actor_id IS NOT NULL',
    whereArgs: [eventId, messageId, senderId],
    limit: 1,
  );
  if (events.isEmpty) throw StateError('回调事件不存在或不属于这条消息');
  final event = events.single;
  final rows = await txn.query(
    'messages',
    columns: ['interactive_json', 'kind'],
    where: 'id = ?',
    whereArgs: [messageId],
    limit: 1,
  );
  if (rows.isEmpty || rows.single['kind'] == 'system')
    throw StateError('原消息已撤回或删除');
  final card = InteractiveMessage.fromJson(
    jsonDecode(rows.single['interactive_json'] as String)
        as Map<String, dynamic>,
  );
  if (event['status'] == 'completed')
    return (card: card, applied: false, status: 'completed');
  if (event['status'] == 'expired')
    return (card: card, applied: false, status: 'expired');
  if (event['status'] != 'processing') throw StateError('这次回调当前未在处理，请先读取最新状态');
  final actor = event['actor_id'] as String;
  final participant = card.participants[actor];
  final now = DateTime.now().microsecondsSinceEpoch;
  final callback = participant?['callback'] as Map?;
  if (participant?['revision'] != event['participant_revision'] ||
      callback?['id'] != eventId) {
    final updates = await transitionInteractiveCallbacks(txn, [
      event,
    ], 'expired');
    return (
      card: updates.isEmpty ? card : updates.single.card,
      applied: false,
      status: 'expired',
    );
  }
  if (['interaction', 'participation', 'states'].any(result.containsKey)) {
    throw ArgumentError('回调结果使用 title、body、buttons；修改共享规则请另行更新定义');
  }
  final presentation = InteractiveMessage.fromDefinition({
    ...card.toJson(),
    'title': result['title'],
    'body': result['body'],
    'buttons': result['buttons'],
    'buttonColumns':
        result['buttonColumns'] ?? card.viewFor(actor).buttonColumns,
  });
  final next = InteractiveMessage.fromJson({
    ...card.toJson(includeParticipants: true),
    'participants': {
      ...card.participants,
      actor: {
        ...participant!,
        'revision': (participant['revision'] as int) + 1,
        'title': presentation.title,
        'body': presentation.body,
        'buttons': presentation.buttons,
        'buttonColumns': presentation.buttonColumns,
        'callback': {
          'id': eventId,
          'buttonId': callback?['buttonId'] ?? participant['buttonId'],
          'status': 'completed',
          'updatedAt': now,
        },
      },
    },
  });
  await txn.update(
    'messages',
    {'interactive_json': jsonEncode(next.toJson(includeParticipants: true))},
    where: 'id = ?',
    whereArgs: [messageId],
  );
  await txn.update(
    'message_callbacks',
    {'status': 'completed', 'processed_at': now},
    where: 'id = ?',
    whereArgs: [eventId],
  );
  return (card: next, applied: true, status: 'completed');
});
