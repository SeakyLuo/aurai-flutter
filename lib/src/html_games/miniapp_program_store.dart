import 'dart:async';
import 'dart:convert';
import 'miniapp_program_runner.dart';
import 'miniapp_program_scheduler.dart';
import 'package:sqflite/sqflite.dart';
import '../domain/agent_models.dart';
import '../domain/interactive_message.dart';
import '../domain/message_sender.dart';
import 'miniapp_program_capabilities.dart';
import 'html_app_store.dart';
import 'html_game_session.dart';
import 'miniapp_program.dart';
import 'miniapp_capability_protocol.dart';

class MiniappProgramChange {
  MiniappProgramChange(this.conversationId, this.messageId);
  final String conversationId, messageId;
  final messages = <({AgentMessage message, bool wakeAi})>[];
  final cards = <String, InteractiveMessage>{};
  final replyStates = <String, bool>{};
  bool memberNamesChanged = false;
  void publish() {
    HtmlGameSignals.changes.add(messageId);
    MiniappProgramStore.changes.add(this);
  }
}

/// Reducers cannot access databases or Java. Their effects commit with state.
class MiniappProgramStore {
  MiniappProgramStore(
    this.database, {
    this.capabilities = const MiniappProgramCapabilities(),
    this.runner = const PlatformMiniappProgramRunner(),
    this.scheduler = const MiniappProgramScheduler(),
  });
  final MiniappProgramCapabilities capabilities;
  final MiniappProgramRunner runner;
  final MiniappProgramScheduler scheduler;
  final Database database;
  static final changes = StreamController<MiniappProgramChange>.broadcast();

  static Future<List<Map<String, Object?>>> members(
    DatabaseExecutor db,
    String conversationId, {
    bool avatars = false,
  }) async {
    final roster = await db.query(
      'message_senders',
      columns: [
        'id',
        'name',
        'kind',
        if (avatars) ...['avatar_icon', 'avatar_color', 'avatar_path'],
      ],
      where:
          'id IN (SELECT sender_id FROM conversation_members WHERE conversation_id = ? AND left_at IS NULL)',
      whereArgs: [conversationId],
    );
    final details = await db.query(
      'group_member_details',
      columns: ['sender_id', 'nickname'],
      where: "conversation_id = ? AND nickname != ''",
      whereArgs: [conversationId],
    );
    final names = {
      for (final row in details) row['sender_id']: row['nickname'],
    };
    return [
      for (final member in roster)
        {
          ...member,
          'originalName': member['name'],
          'name': names[member['id']] ?? member['name'],
        },
    ];
  }

  Future<Map<String, Object?>> event(
    String conversationId,
    String messageId,
    String actorId,
    Map<String, Object?> args,
  ) async {
    late MiniappProgramChange change;
    final result = await database.transaction((txn) async {
      change = await reduce(
        txn,
        conversationId,
        messageId,
        actorId,
        eventId: args['eventId'] as String,
        action: args['action'] as String,
        data: args['data'],
        expectedVersion: args['expectedVersion'] as int?,
      );
      final rows = await txn.query(
        'html_games',
        columns: ['version', 'state_json'],
        where: 'message_id = ?',
        whereArgs: [messageId],
      );
      return {
        'accepted': true,
        'eventId': args['eventId'],
        'version': rows.single['version'],
        'state': MiniappProgram.decode(rows.single['state_json']),
      };
    });
    change.publish();
    return result;
  }

  Future<MiniappProgramChange> reduce(
    DatabaseExecutor txn,
    String conversationId,
    String messageId,
    String actorId, {
    required String eventId,
    required String action,
    Object? data,
    String? cardId,
    int? expectedVersion,
  }) async {
    final rows = await txn.query(
      'html_games',
      where:
          "message_id = ? AND conversation_id = ? AND message_id IN (SELECT id FROM messages WHERE kind = 'html_game')",
      whereArgs: [messageId, conversationId],
    );
    if (rows.isEmpty) throw StateError('小程序消息已撤回或删除');
    final row = rows.single;
    final messages = await txn.query(
      'messages',
      columns: ['sender_id'],
      where: 'id = ?',
      whereArgs: [messageId],
    );
    final app = await HtmlAppStore.load(txn, row['app_id'] as String);
    final code = await HtmlAppStore.code(app);
    final script = MiniappProgram.source(code);
    if (script == null) throw StateError('小程序没有事件处理程序');
    final declared = MiniappCapabilityProtocol.declarations(code);
    final roster = await members(txn, conversationId, avatars: true);
    final senders = {
      for (final member in roster)
        member['id'] as String: MessageSender.fromRow(member),
    };
    if (actorId != 'system:timer' && !roster.any((m) => m['id'] == actorId)) {
      throw StateError('你不是当前群成员');
    }
    final saved = await txn.query(
      'app_state',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [MiniappProgram.key(messageId)],
    );
    final runtime = MiniappProgram.decode(saved.single['value']);
    final bindings = (runtime['bindings'] as Map).cast<String, Object?>();
    final delegatedPlayer = data is Map ? data['submitForPlayerId'] : null;
    final actorView = (runtime['privateViews'] as Map)[actorId] as Map?;
    final canSubmitForPlayers = actorView?['canSubmitForPlayers'] == true;
    if (delegatedPlayer != null &&
        delegatedPlayer != actorId &&
        !canSubmitForPlayers) {
      throw StateError('只有主持人或创建人可以代玩家提交');
    }
    if (cardId == null &&
        (delegatedPlayer == null || delegatedPlayer == actorId) &&
        bindings.values.any((raw) {
          final binding = raw as Map;
          return binding['action'] == action &&
              (binding['actors'] as List).contains(actorId);
        })) {
      throw StateError('请操作对应的交互消息，提交会同时更新消息和小程序');
    }
    if (cardId != null) {
      final binding = bindings[cardId] as Map?;
      if (binding == null ||
          binding['action'] != action ||
          !(binding['actors'] as List).contains(actorId)) {
        throw StateError('这张行动卡已结束或不属于你');
      }
      data = {'context': binding['data'], 'value': data};
    }
    final request = jsonEncode({
      'actorId': actorId,
      'action': action,
      'data': data,
      if (expectedVersion != null) 'expectedVersion': expectedVersion,
    });
    final duplicates = await txn.query(
      'html_game_events',
      columns: ['request_json'],
      where: 'id = ? AND message_id = ?',
      whereArgs: [eventId, messageId],
    );
    final change = MiniappProgramChange(conversationId, messageId);
    if (duplicates.isNotEmpty) {
      if (duplicates.single['request_json'] != request)
        throw StateError('操作编号已被使用');
      return change;
    }
    if (expectedVersion != null && expectedVersion != row['version']) {
      throw StateError('小程序已更新，请重新读取后提交');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final output = await runner.run(
      MiniappCapabilityProtocol.wrap(script, declared),
      {
        'state': runtime['state'],
        'event': {'actorId': actorId, 'action': action, 'data': data},
        'members': roster,
        'ownerId': messages.single['sender_id'],
        'messageId': messageId,
        'now': now,
      },
    );
    final calls = MiniappCapabilityCalls(output, declared);
    final nicknames = calls.nicknames;
    await capabilities.members.setNicknames(
      txn,
      conversationId,
      actorId: actorId,
      nicknames: nicknames,
    );
    change.memberNamesChanged = nicknames.isNotEmpty;
    final effects = calls.messages;
    final views = (output['privateViews'] as Map? ?? const {})
        .cast<String, Object?>();
    final memberIds = roster.map((m) => m['id'] as String).toSet();
    final replyStates = calls.replyStates;
    final agents = roster
        .where((m) => m['kind'] == 'agent')
        .map((m) => m['id'] as String)
        .toSet();
    final replyChange = await capabilities.replies.apply(
      txn,
      conversationId: conversationId,
      messageId: messageId,
      agents: agents,
      states: replyStates,
      before: (runtime['replyBefore'] as Map? ?? const {})
          .cast<String, Object?>(),
      release: calls.releaseReplies,
    );
    final replyBefore = replyChange.before;
    change.replyStates.addAll(replyChange.changed);
    if (views.keys.any((id) => !memberIds.contains(id)))
      throw ArgumentError('私密视图接收人必须是当前群成员');
    final closeKeys = calls.closeKeys;
    change.cards.addAll(
      await capabilities.cards.submitForPlayer(
        txn,
        conversationId: conversationId,
        messageId: messageId,
        actorId: actorId,
        delegatedPlayer: delegatedPlayer,
        canSubmitForPlayers: canSubmitForPlayers,
        senders: senders,
        bindings: bindings,
        submissions: calls.submissions,
      ),
    );
    final closing = [
      for (final entry in bindings.entries)
        if (closeKeys.contains((entry.value as Map)['key'])) entry.key,
    ];
    change.cards.addAll(await capabilities.cards.close(txn, closing));
    for (final id in closing) {
      bindings.remove(id);
    }
    change.messages.addAll(
      await capabilities.messages.emit(
        txn,
        conversationId: conversationId,
        messageId: messageId,
        actorId: actorId,
        memberIds: memberIds,
        agents: agents,
        senders: senders,
        bindings: bindings,
        effects: effects,
      ),
    );
    final view = (output['view'] as Map).cast<String, Object?>();
    final wakeAt = calls.timerChanged
        ? calls.wakeAt
        : actorId == 'system:timer'
        ? null
        : runtime['wakeAt'] as int?;
    if (calls.timerChanged && wakeAt != null && wakeAt <= now) {
      throw ArgumentError('定时回调必须晚于当前时间');
    }
    final next = {
      'state': output['state'],
      'privateViews': views,
      'bindings': bindings,
      'wakeAt': wakeAt,
      'replyBefore': replyBefore,
      'conversationId': conversationId,
      'messageId': messageId,
    };
    await txn.update(
      'app_state',
      {'value': jsonEncode(next)},
      where: 'key = ?',
      whereArgs: [MiniappProgram.key(messageId)],
    );
    final version = (row['version'] as int) + 1;
    await txn.update(
      'html_games',
      {'state_json': jsonEncode(view), 'version': version, 'preview': null},
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
    await txn.insert('html_game_events', {
      'id': eventId,
      'message_id': messageId,
      'actor_id': actorId,
      'version': version,
      'request_json': request,
      'snapshot_json': jsonEncode({'state': view, 'version': version}),
      'created_at': now * 1000,
    });
    return change;
  }

  static Future<MiniappProgramChange?> cancel(
    DatabaseExecutor txn,
    String conversationId,
    String messageId, {
    MiniappProgramCapabilities capabilities =
        const MiniappProgramCapabilities(),
  }) async {
    final rows = await txn.query(
      'app_state',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [MiniappProgram.key(messageId)],
    );
    if (rows.isEmpty) return null;
    final runtime = MiniappProgram.decode(rows.single['value']);
    final change = MiniappProgramChange(conversationId, messageId);
    final before = (runtime['replyBefore'] as Map? ?? const {})
        .cast<String, Object?>();
    final bindings = (runtime['bindings'] as Map).cast<String, Object?>();
    change.replyStates.addAll(
      await capabilities.replies.restore(txn, conversationId, before),
    );
    change.cards.addAll(await capabilities.cards.close(txn, bindings.keys));
    final batch = txn.batch();
    batch.delete(
      'app_state',
      where: 'key = ?',
      whereArgs: [MiniappProgram.key(messageId)],
    );
    await batch.commit(noResult: true);
    return change;
  }

  Future<void> tick() async {
    final change = await scheduler.tick(
      database,
      (txn, runtime) => reduce(
        txn,
        runtime['conversationId'] as String,
        runtime['messageId'] as String,
        'system:timer',
        eventId: 'timer:${runtime['messageId']}:${runtime['wakeAt']}',
        action: 'timer',
      ),
    );
    change?.publish();
  }

  Future<int?> nextWake() => scheduler.nextWake(database);
}
