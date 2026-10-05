import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../domain/message_sender.dart';
import 'html_event_identity.dart';
import 'miniapp_program.dart';
import 'miniapp_program_store.dart';

/// Recovery runs only the committed checkpoint, never the original reducer.
class MiniappContextRecovery {
  static const action = 'context.compact.retry';

  static Future<Map<String, Object?>> _game(
    DatabaseExecutor db,
    String conversationId,
    String messageId,
  ) async {
    final games = await db.query(
      'html_games',
      columns: ['app_id'],
      where:
          "message_id = ? AND conversation_id = ? AND message_id IN (SELECT id FROM messages WHERE kind = 'html_game')",
      whereArgs: [messageId, conversationId],
    );
    if (games.isEmpty) throw StateError('小程序消息已撤回或删除');
    return games.single;
  }

  static Future<bool> _allowed(
    DatabaseExecutor db,
    String conversationId,
    String messageId,
    String actorId,
    String initiatorId,
    Map<String, Object?> game,
  ) async {
    final membership = await db.query(
      'conversation_members',
      columns: ['sender_id'],
      where: 'conversation_id = ? AND sender_id = ? AND left_at IS NULL',
      whereArgs: [conversationId, actorId],
      limit: 1,
    );
    if (membership.isEmpty) return false;
    if (actorId == initiatorId) return true;
    final appId = game['app_id'] as String?;
    if (appId == null) {
      final messages = await db.query(
        'messages',
        columns: ['sender_id'],
        where: 'id = ?',
        whereArgs: [messageId],
      );
      return messages.single['sender_id'] == actorId;
    }
    // Installed copies use the original application's creator and team.
    final apps = await db.query(
      'html_apps',
      columns: ['id', 'creator_id'],
      where:
          'id = COALESCE((SELECT source_id FROM miniapp_installations WHERE app_id = ?), ?)',
      whereArgs: [appId, appId],
    );
    if (apps.isEmpty) throw StateError('原小程序已不存在');
    final app = apps.single;
    if (app['creator_id'] == actorId) return true;
    return (await db.query(
      'miniapp_developers',
      columns: ['sender_id'],
      where: 'app_id = ? AND sender_id = ?',
      whereArgs: [app['id'], actorId],
      limit: 1,
    )).isNotEmpty;
  }

  static Future<Map<String, Object?>?> pending(
    DatabaseExecutor db,
    String conversationId,
    String messageId,
    String actorId,
  ) async {
    final rows = await db.query(
      'app_state',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['context_compaction:$conversationId'],
    );
    if (rows.isEmpty) return null;
    final change = MiniappProgram.decode(rows.single['value']);
    if (change['messageId'] != messageId) return null;
    final compaction = change['contextCompaction'] as Map;
    final events = await db.query(
      'html_game_events',
      columns: ['actor_id'],
      where: 'id = ? AND message_id = ?',
      whereArgs: [compaction['eventId'], messageId],
    );
    final game = await _game(db, conversationId, messageId);
    final allowed = await _allowed(
      db,
      conversationId,
      messageId,
      actorId,
      events.single['actor_id'] as String,
      game,
    );
    return {
      'stateCommitted': true,
      'contextCompacted': false,
      'canRetry': allowed,
      if (allowed)
        'retry': {
          'messageId': messageId,
          'eventId': (jsonDecode(compaction['eventId'] as String) as List)[1],
          'expectedVersion': null,
          'action': action,
          'data': <String, Object?>{},
        },
    };
  }

  static Future<MiniappProgramChange> resume(
    DatabaseExecutor db,
    String conversationId,
    String messageId,
    String actorId,
    Map<String, Object?> args,
  ) async {
    if (args['expectedVersion'] != null ||
        args['data'] is! Map ||
        (args['data'] as Map).isNotEmpty) {
      throw ArgumentError('恢复压缩使用空版本和空数据，不提交原操作参数');
    }
    final identity = htmlEventIdentity(messageId, args['eventId'] as String);
    final game = await _game(db, conversationId, messageId);
    final events = await db.query(
      'html_game_events',
      columns: ['actor_id', 'snapshot_json'],
      where: 'id = ? AND message_id = ?',
      whereArgs: [identity, messageId],
    );
    if (events.isEmpty) throw StateError('原操作不存在');
    if (!await _allowed(
      db,
      conversationId,
      messageId,
      actorId,
      events.single['actor_id'] as String,
      game,
    )) {
      throw StateError('只有发起人、小程序创建人或开发团队成员可以恢复压缩');
    }
    final snapshot = MiniappProgram.decode(events.single['snapshot_json']);
    final pending = snapshot['pendingContextChange'] as Map?;
    if (pending == null) {
      if (snapshot['contextCompacted'] != true) {
        throw StateError('该操作没有待恢复的上下文压缩');
      }
      return MiniappProgramChange(conversationId, messageId);
    }
    final requests = await db.query(
      'app_state',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['context_compaction:$conversationId'],
    );
    if (requests.isEmpty ||
        (MiniappProgram.decode(requests.single['value'])['contextCompaction']
                as Map)['eventId'] !=
            identity) {
      throw StateError('上下文压缩请求已取消或被替换');
    }
    final roster = await MiniappProgramStore.members(
      db,
      conversationId,
      avatars: true,
    );
    final resumed = MiniappProgramChange.fromJson(pending, {
      for (final member in roster)
        member['id'] as String: MessageSender.fromRow(member),
    });
    final boundary = await db.query(
      'messages',
      columns: ['id', 'created_at'],
      where:
          "conversation_id = ? AND kind NOT IN ('message_failure', 'reasoning') AND NOT (role = 'assistant' AND text = '')",
      whereArgs: [conversationId],
      orderBy: 'created_at DESC, id DESC',
      limit: 1,
    );
    resumed.contextCompaction = MiniappContextCompaction(
      eventId: identity,
      instructions: resumed.contextCompaction!.instructions,
      throughMessageId: boundary.single['id'] as String,
      throughCreatedAt: boundary.single['created_at'] as int,
    );
    final value = resumed.toJson();
    final batch = db.batch();
    batch.update(
      'html_game_events',
      {
        'snapshot_json': jsonEncode({
          ...snapshot,
          'pendingContextChange': value,
        }),
      },
      where: 'id = ?',
      whereArgs: [identity],
    );
    batch.update(
      'app_state',
      {'value': jsonEncode(value)},
      where: 'key = ?',
      whereArgs: ['context_compaction:$conversationId'],
    );
    await batch.commit(noResult: true);
    return resumed;
  }
}
