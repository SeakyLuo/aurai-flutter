import 'dart:convert';
import '../storage/message_callbacks.dart';
import 'html_game_store.dart';

extension HtmlMessageInteraction on HtmlGameStore {
  Future<Map<String, Object?>> submitInteraction(
    String conversationId,
    String messageId,
    Map<String, Object?> args,
  ) async {
    final eventId = args['eventId'];
    final action = args['action'];
    if (eventId is! String ||
        eventId.isEmpty ||
        eventId.length > 100 ||
        action is! String ||
        action.trim().isEmpty ||
        action.length > 1000 ||
        args['notifyAi'] is! bool)
      throw ArgumentError('操作需要 eventId、action 和 notifyAi');
    final result = await database.transaction((txn) async {
      final rows = await txn.query(
        'html_games',
        where:
            "message_id = ? AND conversation_id = ? AND message_id IN (SELECT id FROM messages WHERE kind = 'html_game')",
        whereArgs: [messageId, conversationId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('消息已撤回或删除');
      final row = rows.single;
      if (args['notifyAi'] == true) {
        await MessageCallbacks.enqueue(
          txn,
          id: eventId,
          messageId: messageId,
          conversationId: conversationId,
          senderId: row['creator_id'] as String,
          payload: {'action': action, 'data': args['data'], 'source': 'html'},
        );
      }
      return {'accepted': true, 'eventId': eventId};
    });
    if (args['notifyAi'] == true) MessageCallbacks.changes.add(null);
    return result;
  }

  Future<Map<String, Object?>> updateMessage(
    String operation,
    String conversationId,
    String senderId,
    Map<String, Object?> args,
  ) => database.transaction((txn) async {
    final id = args['messageId'] as String;
    final rows = await txn.query(
      'html_games',
      where:
          "message_id = ? AND conversation_id = ? AND message_id IN (SELECT id FROM messages WHERE kind = 'html_game')",
      whereArgs: [id, conversationId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('HTML 消息不存在或已撤回');
    final row = rows.single;
    if (row['creator_id'] != senderId) throw StateError('只能读取或更新自己创建的 HTML 消息');
    final state = jsonDecode(row['state_json'] as String);
    if (operation == 'readHtmlMessage')
      return {
        'messageId': id,
        'version': row['version'],
        'title': row['title'],
        'html': row['html'],
        'backgroundMode': row['background_mode'],
        'state': state,
      };
    if (args['expectedVersion'] != row['version'])
      throw StateError('消息已更新，请重新读取版本');
    final html = args['html'] as String?;
    final background = args['backgroundMode'] as String?;
    if (background != null &&
        !['message', 'transparent'].contains(background)) {
      throw ArgumentError('backgroundMode 必须为 message 或 transparent');
    }
    if (html != null &&
        (html.trim().isEmpty || utf8.encode(html).length > 256 * 1024))
      throw ArgumentError('HTML 不能为空且最多 256 KB');
    final nextState = args['state'] == null
        ? row['state_json'] as String
        : jsonEncode(args['state']);
    if (utf8.encode(nextState).length > 65536)
      throw ArgumentError('状态最多 64 KB');
    if (nextState == row['state_json'] &&
        (html == null || html == row['html']) &&
        (background == null || background == row['background_mode']))
      return {'updated': false, 'version': row['version']};
    final version = (row['version'] as int) + 1;
    await txn.update(
      'html_games',
      {
        'state_json': nextState,
        if (html != null) 'html': html,
        if (background != null) 'background_mode': background,
        'version': version,
        'preview': null,
      },
      where: 'message_id = ?',
      whereArgs: [id],
    );
    return {'updated': true, 'version': version};
  });
}
