import 'dart:convert';
import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import '../domain/agent_models.dart';
import '../domain/message_sender.dart';
import '../storage/conversation_rows.dart';
import 'html_game.dart';

class HtmlGameStore {
  HtmlGameStore(this.database);
  final Database database;
  static const retryColumn =
      "EXISTS (SELECT 1 FROM html_game_receipts WHERE processed_at IS NULL AND attempts >= 3 AND event_id IN (SELECT id FROM html_game_events WHERE message_id = html_games.message_id)) AS retry_available";
  Future<HtmlGameCard> card(String id) async {
    final rows = await database.rawQuery(
      "SELECT title, preview, background_mode, display_mode, display_width, display_height, version, status, $retryColumn FROM html_games WHERE message_id = ? AND message_id IN (SELECT id FROM messages WHERE kind = 'html_game')",
      [id],
    );
    if (rows.isEmpty) throw StateError('游戏已被删除或撤回');
    return HtmlGameCard.fromRow(rows.single);
  }

  Future<void> retryNotifications(String id) async {
    await database.rawUpdate(
      'UPDATE html_game_receipts SET attempts = 0 WHERE processed_at IS NULL AND attempts >= 3 AND event_id IN (SELECT id FROM html_game_events WHERE message_id = ?)',
      [id],
    );
  }

  Future<HtmlGame> load(String conversationId, String messageId) async =>
      _load(database, conversationId, messageId);

  Future<HtmlGame> _load(
    DatabaseExecutor db,
    String conversationId,
    String id,
  ) async {
    final rows = await db.rawQuery(
      "SELECT *, $retryColumn FROM html_games WHERE message_id = ? AND conversation_id = ? AND message_id IN (SELECT id FROM messages WHERE kind = ?)",
      [id, conversationId, 'html_game'],
    );
    if (rows.isEmpty) throw StateError('游戏已被删除或撤回');
    return HtmlGame.fromRow(rows.single);
  }

  static void checkJson(Object? value, int limit, String label) {
    if (utf8.encode(jsonEncode(value)).length > limit)
      throw ArgumentError('$label过大');
  }

  Future<Set<String>> _members(
    DatabaseExecutor db,
    String conversationId,
  ) async {
    final rows = await db.query(
      'conversation_members',
      columns: ['sender_id'],
      where: 'conversation_id = ? AND left_at IS NULL',
      whereArgs: [conversationId],
    );
    return rows.map((r) => r['sender_id'] as String).toSet();
  }

  Future<AgentMessage> create({
    required String conversationId,
    required MessageSender creator,
    required Map<String, Object?> args,
    bool standalone = false,
    bool groupMessage = true,
  }) => database.transaction((txn) async {
    final title = (args['title'] as String).trim();
    final html = args['html'] as String;
    final width = args['width'] as int?;
    final height = args['height'] as int? ?? 320;
    final displayMode = args['displayMode'] as String? ?? 'hybrid';
    final backgroundMode = args['backgroundMode'] as String? ?? 'message';
    if (!['message', 'transparent'].contains(backgroundMode)) {
      throw ArgumentError('backgroundMode 必须为 message 或 transparent');
    }
    if (height < 180 ||
        height > 640 ||
        (width != null && (width < 180 || width > 600)))
      throw ArgumentError('卡片高度需在 180–640 之间，宽度可自适应或设为 180–600');
    final state = (args['state'] as Map).cast<String, Object?>();
    final participants = List<String>.from(args['participants'] as List);
    final turn = args['turnSenderId'] as String?;
    if (title.isEmpty ||
        title.length > 100 ||
        html.trim().isEmpty ||
        utf8.encode(html).length > 256 * 1024)
      throw ArgumentError('请提供标题和不超过 256 KB 的 HTML');
    checkJson(state, 64 * 1024, '游戏状态');
    final members = standalone
        ? <String>{}
        : await _members(txn, conversationId);
    if (!standalone &&
        (participants.length < 2 ||
            participants.length > 8 ||
            participants.toSet().length != participants.length ||
            !participants.contains(MessageSender.localUser.id) ||
            !participants.contains(creator.id) ||
            participants.any((id) => !members.contains(id)) ||
            (turn != null && !participants.contains(turn))))
      throw ArgumentError('请选择包含你和用户的 2–8 位当前群成员，并指定有效的下一位玩家');
    final message = AgentMessage(
      id: newMessageId(),
      role: AgentMessageRole.assistant,
      senderId: creator.id,
      sender: creator,
      text: title,
      createdAt: DateTime.now(),
      isGroupMessage: groupMessage,
      htmlGame: HtmlGameCard(
        title: title,
        width: width,
        height: height,
        displayMode: displayMode,
        backgroundMode: backgroundMode,
      ),
    );
    await txn.insert('messages', messageRow(conversationId, message));
    await txn.insert('html_games', {
      'message_id': message.id,
      'conversation_id': conversationId,
      'creator_id': creator.id,
      'title': title,
      'html': html,
      'display_mode': displayMode,
      'background_mode': backgroundMode,
      'stateful': args['stateful'] == true ? 1 : 0,
      'display_width': width,
      'display_height': height,
      'state_json': jsonEncode(state),
      'version': 0,
      'participants_json': jsonEncode(participants),
      'status': 'active',
      'turn_sender_id': turn,
      'updated_at': message.createdAt.microsecondsSinceEpoch,
    });
    await txn.rawUpdate(
      'UPDATE conversations SET message_count = message_count + 1, preview = ?, updated_at = ? WHERE id = ?',
      [title, message.createdAt.microsecondsSinceEpoch, conversationId],
    );
    final initialEventId = '${message.id}:created';
    final snapshot = (await _load(txn, conversationId, message.id)).snapshot();
    await txn.insert('html_game_events', {
      'id': initialEventId,
      'message_id': message.id,
      'actor_id': creator.id,
      'version': 0,
      'request_json': jsonEncode({'action': '游戏已创建'}),
      'snapshot_json': jsonEncode(snapshot),
      'created_at': message.createdAt.microsecondsSinceEpoch,
    });
    if (turn != null &&
        turn != creator.id &&
        turn != MessageSender.localUser.id) {
      await txn.insert('html_game_receipts', {
        'event_id': initialEventId,
        'conversation_id': conversationId,
        'sender_id': turn,
      });
    }
    return message;
  });

  /// Both JS and AI submit complete states. No WebView is needed for an AI move.
  Future<Map<String, Object?>> apply(
    String conversationId,
    String messageId,
    String actorId,
    Map<String, Object?> args,
  ) => database.transaction((txn) async {
    final game = await _load(txn, conversationId, messageId);
    final eventId = args['eventId'] as String;
    final expected = args['expectedVersion'] as int;
    final nextState = (args['state'] as Map).cast<String, Object?>();
    final action = (args['action'] as String).trim();
    final turn = args['turnSenderId'] as String?;
    final status = args['status'] as String;
    final recipients = List<String>.from(args['notifySenderIds'] as List);
    if (eventId.isEmpty ||
        eventId.length > 100 ||
        action.isEmpty ||
        action.length > 1000 ||
        !['active', 'finished'].contains(status) ||
        recipients.length > 8 ||
        recipients.toSet().length != recipients.length)
      throw ArgumentError('游戏事件格式不正确');
    checkJson(nextState, 64 * 1024, '游戏状态');
    final request = jsonEncode({
      'actorId': actorId,
      'expectedVersion': expected,
      'state': nextState,
      'action': action,
      'turnSenderId': turn,
      'status': status,
      'notifySenderIds': recipients,
    });
    final members = await _members(txn, conversationId);
    if (!members.contains(actorId) || !game.participants.contains(actorId))
      throw StateError('你不是这局游戏的当前参与者');
    final duplicates = await txn.query(
      'html_game_events',
      columns: ['message_id', 'request_json'],
      where: 'id = ?',
      whereArgs: [eventId],
    );
    if (duplicates.isNotEmpty) {
      if (duplicates.single['message_id'] != messageId ||
          duplicates.single['request_json'] != request)
        throw StateError('操作编号已被另一项操作使用');
      return {'applied': true, 'duplicate': true, ...game.snapshot()};
    }
    if (game.version != expected)
      return {
        'applied': false,
        'reason': 'version_conflict',
        ...game.snapshot(),
      };
    if (game.status == 'finished') throw StateError('这局游戏已结束');
    if (game.turnSenderId != null && game.turnSenderId != actorId)
      throw StateError('还没有轮到你');
    if ((turn != null &&
            (!members.contains(turn) || !game.participants.contains(turn))) ||
        recipients.any(
          (id) =>
              id == actorId ||
              id == MessageSender.localUser.id ||
              !members.contains(id) ||
              !game.participants.contains(id),
        ))
      throw ArgumentError('下一位玩家和通知对象必须是当前参与者');
    final snapshot = {
      ...game.snapshot(),
      'state': nextState,
      'version': expected + 1,
      'turnSenderId': turn,
      'status': status,
    };
    final now = DateTime.now().microsecondsSinceEpoch;
    await txn.update(
      'html_games',
      {
        'state_json': jsonEncode(nextState),
        'version': expected + 1,
        'status': status,
        'turn_sender_id': turn,
        'preview': null,
        'updated_at': now,
      },
      where: 'message_id = ? AND version = ?',
      whereArgs: [messageId, expected],
    );
    await txn.insert('html_game_events', {
      'id': eventId,
      'message_id': messageId,
      'actor_id': actorId,
      'version': expected + 1,
      'request_json': request,
      'snapshot_json': jsonEncode(snapshot),
      'created_at': now,
    });
    final batch = txn.batch();
    for (final id in recipients) {
      batch.insert('html_game_receipts', {
        'event_id': eventId,
        'conversation_id': conversationId,
        'sender_id': id,
      });
    }
    await batch.commit(noResult: true);
    return {'applied': true, ...snapshot};
  });

  Future<void> savePreview(String id, int version, Uint8List bytes) async {
    if (bytes.length > 256 * 1024) return;
    await database.update(
      'html_games',
      {'preview': bytes},
      where: 'message_id = ? AND version = ?',
      whereArgs: [id, version],
    );
  }

  Future<List<Map<String, Object?>>> pending(
    String conversationId,
    String senderId,
  ) => database.rawQuery(
    '''SELECT id, message_id, actor_id, snapshot_json, request_json FROM html_game_events WHERE id IN (
    SELECT event_id FROM html_game_receipts WHERE conversation_id = ? AND sender_id = ? AND processed_at IS NULL AND attempts < 3
  ) AND message_id IN (SELECT id FROM messages WHERE kind = 'html_game') ORDER BY created_at, id LIMIT 20''',
    [conversationId, senderId],
  );

  Future<void> finishEvents(
    String senderId,
    List<String> eventIds, {
    required bool success,
  }) async {
    if (eventIds.isEmpty) return;
    final slots = List.filled(eventIds.length, '?').join(',');
    await database.rawUpdate(
      success
          ? 'UPDATE html_game_receipts SET processed_at = ? WHERE sender_id = ? AND event_id IN ($slots)'
          : 'UPDATE html_game_receipts SET attempts = attempts + 1 WHERE sender_id = ? AND event_id IN ($slots)',
      [
        if (success) DateTime.now().microsecondsSinceEpoch,
        senderId,
        ...eventIds,
      ],
    );
  }

  Future<List<Map<String, Object?>>> pendingWake() => database.rawQuery(
    '''SELECT DISTINCT conversation_id, sender_id FROM html_game_receipts AS receipt
    WHERE processed_at IS NULL AND attempts < 3
    AND conversation_id IN (SELECT id FROM conversations WHERE archived = 0)
    AND event_id IN (SELECT id FROM html_game_events WHERE message_id IN (SELECT id FROM messages WHERE kind = 'html_game'))
    AND sender_id IN (SELECT sender_id FROM conversation_members WHERE conversation_id = receipt.conversation_id AND left_at IS NULL)
    AND sender_id NOT IN (SELECT sender_id FROM group_participation WHERE conversation_id = receipt.conversation_id AND paused = 1)
    LIMIT 32''',
  );
}
