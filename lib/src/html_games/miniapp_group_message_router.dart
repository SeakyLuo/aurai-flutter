import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../domain/agent_models.dart';
import 'miniapp_program.dart';
import 'miniapp_program_store.dart';

/// Programs intercept publication before a message can enter group history.
class MiniappGroupMessageRouter {
  const MiniappGroupMessageRouter(this.database);
  final Database database;

  Future<Map<String, Object?>?> send(
    String conversationId,
    String actorId,
    Map<String, Object?> message,
    String participation,
  ) async {
    MiniappProgramChange? change;
    final result = await database.transaction<Map<String, Object?>?>((
      txn,
    ) async {
      final routePath = '\$.messageRoutes.${jsonEncode(actorId)}';
      final rows = await txn.query(
        'app_state',
        columns: ['value'],
        where: '''key LIKE 'miniapp-program:%'
          AND json_extract(value, '\$.conversationId') = ?
          AND json_type(value, ?) = 'text'
          AND json_extract(value, '\$.messageId') IN
            (SELECT message_id FROM html_games WHERE conversation_id = ?
             AND message_id IN (SELECT id FROM messages WHERE kind = 'html_game'))''',
        whereArgs: [conversationId, routePath, conversationId],
        limit: 2,
      );
      if (rows.isEmpty) return null;
      if (rows.length > 1) throw StateError('多个小程序正在接管你的发言，请先结束重复的对局');
      if (participation != 'unchanged')
        throw StateError('小程序正在管理比赛接话状态；发送发言时不能同时修改接话状态');
      if ((message['_images'] as List).isNotEmpty ||
          (message['_files'] as List? ?? const []).isNotEmpty ||
          message['quoteMessageId'] != null) {
        throw StateError('当前小程序接管发言，只支持正文；图片、附件和引用不能绕过消息可见范围');
      }
      final runtime = MiniappProgram.decode(rows.single['value']);
      final messageId = runtime['messageId'] as String;
      change = await MiniappProgramStore(database).reduce(
        txn,
        conversationId,
        messageId,
        actorId,
        eventId: newMessageId(),
        action: (runtime['messageRoutes'] as Map)[actorId] as String,
        data: {
          'text': message['text'],
          'markdown': message['markdown'] == true,
        },
      );
      final sent = change!.messages
          .where(
            (entry) =>
                entry.message.senderId == actorId && !entry.message.isSystem,
          )
          .toList();
      if (sent.length != 1) throw StateError('小程序必须发布一条以当前 AI 署名的消息');
      final published = sent.single.message;
      return {
        'sent': true,
        'messageId': published.id,
        'groupId': conversationId,
        'participation': participation,
        'programMessageId': messageId,
        'audience': published.audience,
        'instruction': '消息已由小程序发布，可见范围以返回结果为准，不要重复发送。',
      };
    });
    change?.publish();
    return result;
  }
}
