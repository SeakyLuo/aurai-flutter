import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../domain/interactive_message.dart';
import 'interactive_completion.dart';

Future<InteractiveMessage> withdrawInteractiveVote(
  Database database, {
  required String conversationId,
  required String messageId,
  required String actorId,
  required int revision,
  required int participantRevision,
}) => database.transaction((txn) async {
  final rows = await txn.query(
    'messages',
    columns: ['interactive_json', 'sender_id'],
    where: 'id = ? AND conversation_id = ? AND kind != ?',
    whereArgs: [messageId, conversationId, 'system'],
  );
  if (rows.isEmpty) throw StateError('消息已撤回或删除');
  final card = InteractiveMessage.fromJson(
    jsonDecode(rows.single['interactive_json'] as String)
        as Map<String, dynamic>,
  );
  card.requireViewer(actorId);
  if (card.revision != revision ||
      card.participantRevision(actorId) != participantRevision)
    throw InteractiveMessageChanged(card);
  if (!card.isVote || card.closed || card.engine.phase != 'collecting')
    throw StateError('投票已结束，不能取消投票');
  if (!card.engine.allowChange) throw StateError('这张投票不允许改票');
  final previous = card.choices[actorId];
  if (previous == null) throw StateError('你还没有投票');
  final participant = card.participants[actorId]!;
  final callback = participant['callback'] as Map?;
  if (['queued', 'processing'].contains(callback?['status']))
    throw StateError('正在处理这次投票，请等待结果');
  final now = DateTime.now().microsecondsSinceEpoch;
  final nextParticipant = {...participant}
    ..remove('buttonId')
    ..remove('label')
    ..remove('value')
    ..remove('selections')
    ..remove('reason')
    ..remove('callback');
  nextParticipant['revision'] = participantRevision + 1;
  nextParticipant['updatedAt'] = now;
  var next = InteractiveMessage.fromJson({
    ...card.toJson(includeParticipants: true),
    if (card.shared) 'session': card.engine.withdraw(actorId).runtime,
    'participants': {...card.participants, actorId: nextParticipant},
  });
  await txn.insert('interactive_actions', {
    'message_id': messageId,
    'actor_id': actorId,
    'actor_name': participant['name'],
    'button_id': previous['buttonId'],
    'label': '取消投票',
    'definition_revision': revision,
    'participant_revision': participantRevision + 1,
    'created_at': now,
  });
  if (callback != null)
    await txn.update(
      'message_callbacks',
      {'status': 'expired', 'processed_at': now},
      where: 'id = ? AND processed_at IS NULL',
      whereArgs: [callback['id']],
    );
  next = await enqueueInteractiveCompletion(
    txn,
    conversationId: conversationId,
    messageId: messageId,
    creatorId: rows.single['sender_id'] as String,
    previous: card,
    current: next,
    actorId: actorId,
    actorName: participant['name'] as String,
  );
  await txn.update(
    'messages',
    {'interactive_json': jsonEncode(next.toJson(includeParticipants: true))},
    where: 'id = ?',
    whereArgs: [messageId],
  );
  return next;
});
