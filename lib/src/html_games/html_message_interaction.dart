import '../storage/html_callback_state.dart';
import 'html_app_store.dart';
import '../domain/interactive_message.dart';
import '../storage/interactive_message_store.dart';
import '../domain/message_sender.dart';
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
    if (action == 'aurai:clickButton') {
      final bound = await database.query(
        'html_games',
        columns: ['message_id'],
        where:
            "message_id = ? AND conversation_id = ? AND message_id IN (SELECT id FROM messages WHERE kind = 'html_game')",
        whereArgs: [messageId, conversationId],
        limit: 1,
      );
      if (bound.isEmpty) throw StateError('消息已撤回或删除');
      final data = (args['data'] as Map).cast<String, Object?>();
      final result = await InteractiveMessageStore(database).click(
        conversationId,
        messageId,
        data['buttonId'] as String,
        data['revision'] as int,
        participantRevision: data['participantRevision'] as int,
        actor: MessageSender.localUser,
        inputValue: data['value'],
      );
      InteractiveMessageStore.changes.add(messageId);
      MessageCallbacks.changes.add(null);
      return {
        'accepted': true,
        'eventId': eventId,
        ...result.card.webViewFor(MessageSender.localUser.id),
      };
    }
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
          html: true,
        );
      }
      return {'accepted': true, 'eventId': eventId,
        if (args['notifyAi'] == true)
          ...((await HtmlCallbackState.read(txn, messageId, eventId: eventId)).single)};
    });
    if (args['notifyAi'] == true) {
      HtmlCallbackState.changes.add(messageId);
      MessageCallbacks.changes.add(null);
    }
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
    final authored = row['creator_id'] == senderId;
    if (operation != 'readHtmlMessage' && !authored)
      throw StateError('只能更新自己创建的 HTML 消息');
    final app = await HtmlAppStore.load(txn, row['app_id'] as String);
    final state = jsonDecode(app['state_json'] as String);
    if (operation == 'readHtmlMessage') {
      final messages = await txn.query(
        'messages',
        columns: ['interactive_json'],
        where: 'id = ?',
        whereArgs: [id],
      );
      final raw = messages.single['interactive_json'];
      final interactive = raw == null
          ? null
          : InteractiveMessage.fromJson(
              (jsonDecode(raw as String) as Map).cast<String, Object?>(),
            );
      interactive?.requireViewer(senderId);
      return {
        if (interactive != null) 'interaction': interactive.webViewFor(senderId),
        if (interactive != null) 'presentation': interactive.viewFor(senderId).toJson(),
        if (authored) 'events': await HtmlCallbackState.read(txn, id),
        'messageId': id,
        'version': row['version'],
        'title': row['title'],
        if (authored || args['includePrivate'] == true) ...{
          'html': await HtmlAppStore.code(app),
          ...await HtmlAppStore.reference(app),
        },
        'backgroundMode': row['background_mode'],
        'displayMode': row['display_mode'],
        'width': row['display_width'],
        'conversationId': conversationId,
        if (authored || args['includePrivate'] == true) 'state': state,
        'privateContentIncluded': authored || args['includePrivate'] == true,
      };
    }
    final callbackId = args['callbackEventId'] as String?;
    if (callbackId != null) {
      final event = await HtmlCallbackState.requireEvent(txn, id, callbackId, senderId);
      if (event['status'] == 'completed') {
        return {'updated': false, 'version': row['version'], 'callbackCompleted': true};
      }
      if (event['status'] != 'processing') throw StateError('操作未在处理中，请先重试');
    }
    if (args['expectedVersion'] != row['version'])
      throw StateError('消息已更新，请重新读取版本');
    final html = args['html'] as String?;
    final background = args['backgroundMode'] as String?;
    final title = (args['title'] as String?)?.trim();
    final displayMode = args['displayMode'] as String?;
    final width = args['width'] as int?;
    if (title != null && (title.isEmpty || title.length > 100))
      throw ArgumentError('标题需为 1–100 字');
    if (displayMode != null && !['inline', 'hybrid', 'standalone'].contains(displayMode))
      throw ArgumentError('displayMode 必须为 inline、hybrid 或 standalone');
    if (width != null && (width < 180 || width > 600))
      throw ArgumentError('宽度需为 180–600，或使用 null 自适应');
    final presentation = <String, Object?>{
      if (title != null) 'title': title,
      if (displayMode != null) 'display_mode': displayMode,
      if (args.containsKey('width')) 'display_width': width,
    };
    final presentationChanged = presentation.entries.any((e) => row[e.key] != e.value);
    if (background != null &&
        !['message', 'transparent'].contains(background)) {
      throw ArgumentError('backgroundMode 必须为 message 或 transparent');
    }
    if (html != null &&
        (html.trim().isEmpty || utf8.encode(html).length > 256 * 1024))
      throw ArgumentError('HTML 不能为空且最多 256 KB');
    final nextState = args['state'] == null
        ? app['state_json'] as String
        : jsonEncode(args['state']);
    if (utf8.encode(nextState).length > 65536)
      throw ArgumentError('状态最多 64 KB');
    if (!presentationChanged && nextState == app['state_json'] &&
        html == null &&
        (background == null || background == row['background_mode'])) {
        if (callbackId != null) await HtmlCallbackState.complete(txn, callbackId);
        return {'updated': false, 'version': row['version'],
          if (callbackId != null) 'callbackCompleted': true};
    }
    final version = (row['version'] as int) + 1;
    final sourcePath = html == null ? app['source_path'] as String : await HtmlAppStore.publish(app['id'] as String, html);
    await txn.update('html_apps', {
      'source_path': sourcePath,
      'state_json': nextState,
      'version': version,
      if (title != null) 'title': title,
      'updated_at': DateTime.now().microsecondsSinceEpoch,
    }, where: 'id = ?', whereArgs: [app['id']]);
    await txn.update(
      'html_games',
      {'version': version, 'preview': null},
      where: 'app_id = ?',
      whereArgs: [app['id']],
    );
    if (presentation.isNotEmpty || background != null) {
      await txn.update('html_games', {
        ...presentation,
        if (background != null) 'background_mode': background,
      }, where: 'message_id = ?', whereArgs: [id]);
    }
    if (title != null && title != row['title']) {
      final messages = await txn.query('messages', columns: ['interactive_json'],
        where: 'id = ?', whereArgs: [id], limit: 1);
      final raw = messages.single['interactive_json'] as String?;
      final card = raw == null ? null : (jsonDecode(raw) as Map).cast<String, Object?>();
      if (card != null) {
        card['title'] = title;
        card['revision'] = (card['revision'] as int) + 1;
      }
      final private = card != null && (card['participation'] as Map?)?['audience'] != null;
      final text = private ? '私密交互消息' : title;
      await txn.update('messages', {
        'text': text,
        if (card != null) 'interactive_json': jsonEncode(card),
      }, where: 'id = ?', whereArgs: [id]);
      await txn.update('conversations', {'preview': text},
        where: 'id = ? AND ? = (SELECT id FROM messages WHERE conversation_id = ? ORDER BY created_at DESC, id DESC LIMIT 1)',
        whereArgs: [conversationId, id, conversationId]);
    }
    if (callbackId != null) await HtmlCallbackState.complete(txn, callbackId);
    return {'updated': true, 'version': version,
      if (callbackId != null) 'callbackCompleted': true,
      ...await HtmlAppStore.reference({...app, 'source_path': sourcePath})};
  });
}
