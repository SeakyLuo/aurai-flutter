import 'dart:convert';
import 'html_app_store.dart';
import 'miniapp_program.dart';
import 'html_game_session.dart';
import 'html_store.dart';

/// Edits target one message instance, never its reusable template or other rounds.
class HtmlMessageData {
  HtmlMessageData(this.store);
  final HtmlStore store;

  Future<({bool allowed, String title})> access(String id, String actor) async {
    final rows = await store.database.query(
      'html_games',
      columns: ['creator_id', 'title'],
      where:
          "message_id = ? AND message_id IN (SELECT id FROM messages WHERE kind = 'html_game')",
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('HTML 消息不存在或已撤回');
    final programs = await store.database.query(
      'app_state',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [MiniappProgram.key(id)],
      limit: 1,
    );
    final granted =
        programs.isNotEmpty &&
        ((MiniappProgram.decode(programs.single['value'])['privateViews']
                    as Map)[actor]
                as Map?)?['canEditData'] ==
            true;
    return (
      allowed: rows.single['creator_id'] == actor || granted,
      title: rows.single['title'] as String,
    );
  }

  Future<Map<String, Object?>> invoke(
    String operation,
    String conversationId,
    String actorId,
    Map<String, Object?> args, {
    bool userApproved = false,
  }) async {
    final id = args['messageId'] as String;
    final result = await store.database.transaction((txn) async {
      final games = await txn.query(
        'html_games',
        where:
            "message_id = ? AND conversation_id = ? AND message_id IN (SELECT id FROM messages WHERE kind = 'html_game')",
        whereArgs: [id, conversationId],
        limit: 1,
      );
      if (games.isEmpty) throw StateError('HTML 消息不存在或已撤回');
      final game = games.single;
      final programs = await txn.query(
        'app_state',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [MiniappProgram.key(id)],
        limit: 1,
      );
      final runtime = programs.isEmpty
          ? null
          : MiniappProgram.decode(programs.single['value']);
      if (!userApproved &&
          game['creator_id'] != actorId &&
          ((runtime?['privateViews'] as Map?)?[actorId]
                  as Map?)?['canEditData'] !=
              true)
        throw StateError('请先申请用户授权再读取或修改此消息实例的数据');
      final Object? previous;
      if (runtime != null) {
        previous = {
          'state': runtime['state'],
          'view': jsonDecode(game['state_json'] as String),
          'privateViews': runtime['privateViews'],
        };
      } else if (game['session_data_json'] != null) {
        previous = jsonDecode(game['state_json'] as String);
      } else {
        final app = await HtmlAppStore.load(txn, game['app_id'] as String);
        previous = jsonDecode(app['state_json'] as String);
      }
      if (operation == 'readHtmlData')
        return {
          'messageId': id,
          'version': game['version'],
          'program': runtime != null,
          'data': previous,
        };
      final eventId = args['eventId'] as String;
      final request = jsonEncode({
        'actorId': actorId,
        'data': args['data'],
        'expectedVersion': args['expectedVersion'],
        'action': 'updateHtmlData',
      });
      final events = await txn.query(
        'html_game_events',
        columns: ['request_json', 'version'],
        where: 'id = ? AND message_id = ?',
        whereArgs: [eventId, id],
        limit: 1,
      );
      if (events.isNotEmpty) {
        if (events.single['request_json'] != request)
          throw StateError('操作编号已被使用');
        return {
          'updated': false,
          'duplicate': true,
          'version': events.single['version'],
        };
      }
      if (args['expectedVersion'] != game['version'])
        throw StateError('消息已更新，请重新读取版本');
      final data = (args['data'] as Map).cast<String, Object?>();
      final encoded = jsonEncode(data);
      if (utf8.encode(encoded).length > (runtime == null ? 65536 : 262144))
        throw ArgumentError('HTML 数据超过大小限制');
      final Object? view;
      if (runtime != null) {
        if (data['state'] is! Map ||
            data['view'] is! Map ||
            data['privateViews'] is! Map)
          throw ArgumentError('程序数据需要完整的 state、view、privateViews 对象');
        final members = await txn.query(
          'conversation_members',
          columns: ['sender_id'],
          where: 'conversation_id = ? AND left_at IS NULL',
          whereArgs: [conversationId],
        );
        final ids = members.map((m) => m['sender_id']).toSet();
        if ((data['privateViews'] as Map).keys.any((id) => !ids.contains(id)))
          throw ArgumentError('私密视图接收人必须为当前群成员');
        final next = jsonEncode({
          ...runtime,
          'state': data['state'],
          'privateViews': data['privateViews'],
        });
        if (utf8.encode(next).length > 262144)
          throw ArgumentError('小程序状态最多 256 KB');
        await txn.update(
          'app_state',
          {'value': next},
          where: 'key = ?',
          whereArgs: [MiniappProgram.key(id)],
        );
        view = data['view'];
      } else {
        view = data;
      }
      final version = (game['version'] as int) + 1;
      final now = DateTime.now().microsecondsSinceEpoch;
      await txn.update(
        'html_games',
        {
          'state_json': jsonEncode(view),
          'version': version,
          'preview': null,
          'updated_at': now,
          if (runtime == null && game['session_data_json'] == null)
            'session_data_json': '{}',
        },
        where: 'message_id = ?',
        whereArgs: [id],
      );
      await txn.insert('html_game_events', {
        'id': eventId,
        'message_id': id,
        'actor_id': actorId,
        'version': version,
        'request_json': request,
        'snapshot_json': jsonEncode({'state': view, 'version': version}),
        'created_at': now,
      });
      return {'messageId': id, 'updated': true, 'version': version};
    });
    if (result['updated'] == true) HtmlGameSignals.changes.add(id);
    return result;
  }
}
