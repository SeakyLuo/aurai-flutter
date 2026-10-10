import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../domain/interactive_message.dart';
import 'miniapp_program.dart';
import '../domain/message_sender.dart';
import 'program_card_submission.dart';

/// Host-owned card lifecycle; program output cannot bypass card ownership.
class MiniappCardCapability {
  const MiniappCardCapability();

  Future<Map<String, InteractiveMessage>> close(
    DatabaseExecutor db,
    Iterable<String> messageIds,
  ) async {
    final ids = messageIds.toList();
    if (ids.isEmpty) return {};
    final rows = await db.query(
      'messages',
      columns: ['id', 'interactive_json'],
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
    final changed = <String, InteractiveMessage>{};
    final batch = db.batch();
    for (final row in rows) {
      final card = InteractiveMessage.fromJson(
        MiniappProgram.decode(row['interactive_json']),
      );
      final next = InteractiveMessage.fromJson({
        ...card.toJson(includeParticipants: true),
        'revision': card.revision + 1,
        'participation': {...card.participation, 'closed': true},
        if (card.shared)
          'session': card.engine.settle(closed: true).runtime
        else
          'content': {...card.content, 'children': const <Object?>[]},
      });
      final id = row['id'] as String;
      changed[id] = next;
      batch.update(
        'messages',
        {
          'interactive_json': jsonEncode(
            next.toJson(includeParticipants: true),
          ),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
    return changed;
  }

  Future<Map<String, InteractiveMessage>> submitForPlayer(
    DatabaseExecutor txn, {
    required String conversationId,
    required String messageId,
    required String actorId,
    required Object? delegatedPlayer,
    required bool canSubmitForPlayers,
    required Map<String, MessageSender> senders,
    required Map<String, Object?> bindings,
    required List submissions,
  }) async {
    if (submissions.length > 1) {
      throw ArgumentError('单次事件只能代填一位玩家的一张行动卡');
    }
    if (submissions.isNotEmpty) {
      if (!canSubmitForPlayers) {
        throw StateError('只有主持人或创建人可以代玩家提交');
      }
      final submission = (submissions.single as Map).cast<String, Object?>();
      final bound = bindings.entries.singleWhere(
        (entry) => (entry.value as Map)['key'] == submission['key'],
      );
      final binding = bound.value as Map;
      final playerId = submission['actorId'] as String;
      if (playerId != delegatedPlayer) {
        throw StateError('代填行动卡与指定玩家不一致');
      }
      if (!(binding['actors'] as List).contains(playerId)) {
        throw StateError('该玩家不属于这张行动卡');
      }
      final card = await submitProgramCard(
        txn,
        conversationId: conversationId,
        programId: messageId,
        messageId: bound.key,
        player: senders[playerId]!,
        submitter: senders[actorId]!,
        programAction: binding['action'] as String,
        value: submission['value'],
        reason: submission['reason'] as String?,
      );
      return {bound.key: card};
    }
    return {};
  }
}
