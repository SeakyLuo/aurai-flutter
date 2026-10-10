import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../domain/interactive_message.dart';
import '../html_games/miniapp_program_store.dart';
import 'interactive_completion.dart';

Future<InteractiveMessage> setQuestionnaireCollectionPaused(
  Database database, {
  required String conversationId,
  required String messageId,
  required String actorId,
  required int revision,
  required bool paused,
}) async {
  MiniappProgramChange? programChange;
  final result = await database.transaction((txn) async {
    final rows = await txn.query(
      'messages',
      columns: ['interactive_json', 'sender_id'],
      where: 'id = ? AND conversation_id = ? AND kind != ?',
      whereArgs: [messageId, conversationId, 'system'],
    );
    if (rows.isEmpty) throw StateError('消息已撤回或删除');
    if (rows.single['sender_id'] != actorId)
      throw StateError('只有问卷发起人可以暂停或恢复收集');
    final card = InteractiveMessage.fromJson(
      jsonDecode(rows.single['interactive_json'] as String)
          as Map<String, dynamic>,
    );
    card.requireViewer(actorId);
    if (card.revision != revision) throw InteractiveMessageChanged(card);
    if (!card.isQuestionnaire) throw StateError('只有问卷支持暂停收集');
    if (card.completed) throw StateError('问卷已结束，不能暂停或恢复收集');
    if (card.collectionPaused == paused) return card;
    var next = InteractiveMessage.fromJson({
      ...card.toJson(includeParticipants: true),
      'revision': card.revision + 1,
      'participation': {...card.participation, '_collectionPaused': paused},
    });
    next = await enqueueInteractiveCompletion(
      txn,
      conversationId: conversationId,
      messageId: messageId,
      creatorId: actorId,
      previous: card,
      current: next,
    );
    await txn.update(
      'messages',
      {'interactive_json': jsonEncode(next.toJson(includeParticipants: true))},
      where: 'id = ?',
      whereArgs: [messageId],
    );
    if (card.participation['_programMessage'] case final String programId
        when paused) {
      programChange = await MiniappProgramStore(database).reduce(
        txn,
        conversationId,
        programId,
        actorId,
        eventId: '$messageId:pause:${next.revision}',
        action: card.buttons.single['programEvent'] as String,
        cardId: messageId,
        collectionPaused: true,
      );
      final updated = await txn.query(
        'messages',
        columns: ['interactive_json'],
        where: 'id = ?',
        whereArgs: [messageId],
      );
      next = InteractiveMessage.fromJson(
        jsonDecode(updated.single['interactive_json'] as String)
            as Map<String, dynamic>,
      );
      programChange!.cards[messageId] = next;
    }
    return next;
  });
  await programChange?.publish();
  return result;
}
