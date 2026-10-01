import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import '../domain/agent_models.dart';
import '../domain/interactive_message.dart';
import '../domain/message_sender.dart';
import '../storage/conversation_rows.dart';
import 'html_app_store.dart';
import 'html_game_session.dart';
import 'miniapp_program.dart';

class MiniappProgramChange {
  MiniappProgramChange(this.conversationId, this.messageId);
  final String conversationId, messageId;
  final messages = <({AgentMessage message, bool wakeAi})>[];
  final cards = <String, InteractiveMessage>{};
  final replyStates = <String, bool>{};
  void publish() {
    HtmlGameSignals.changes.add(messageId);
    MiniappProgramStore.changes.add(this);
  }
}

/// Reducers cannot access databases or Java. Their effects commit with state.
class MiniappProgramStore {
  MiniappProgramStore(this.database);
  final Database database;
  static final changes = StreamController<MiniappProgramChange>.broadcast();
  static const _channel = MethodChannel('com.haiskynology.aurai/platform');

  static Future<List<Map<String, Object?>>> members(
    DatabaseExecutor db,
    String conversationId,
  ) => db.query(
    'message_senders',
    columns: ['id', 'name', 'kind'],
    where:
        'id IN (SELECT sender_id FROM conversation_members WHERE conversation_id = ? AND left_at IS NULL)',
    whereArgs: [conversationId],
  );

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
  }) async {
    final rows = await txn.query(
      'html_games',
      where:
          "message_id = ? AND conversation_id = ? AND message_id IN (SELECT id FROM messages WHERE kind = 'html_game')",
      whereArgs: [messageId, conversationId],
    );
    if (rows.isEmpty) throw StateError('小程序消息已撤回或删除');
    final row = rows.single;
    final app = await HtmlAppStore.load(txn, row['app_id'] as String);
    final script = MiniappProgram.source(await HtmlAppStore.code(app));
    if (script == null) throw StateError('小程序没有事件处理程序');
    final roster = await members(txn, conversationId);
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
    final now = DateTime.now().millisecondsSinceEpoch;
    final encoded = await _channel.invokeMethod<String>('runMiniappProgram', {
      'script': script,
      'input': jsonEncode({
        'state': runtime['state'],
        'event': {'actorId': actorId, 'action': action, 'data': data},
        'members': roster,
        'ownerId': MessageSender.localUser.id,
        'now': now,
      }),
    });
    final output = MiniappProgram.decode(encoded);
    final effects = (output['messages'] as List? ?? const []);
    if (effects.length > 32) throw ArgumentError('单次事件最多产生 32 条消息');
    final views = (output['privateViews'] as Map? ?? const {})
        .cast<String, Object?>();
    final memberIds = roster.map((m) => m['id']).toSet();
    final replyStates = (output['replyStates'] as Map? ?? const {})
        .cast<String, bool>();
    final agents = roster
        .where((m) => m['kind'] == 'agent')
        .map((m) => m['id'])
        .toSet();
    if (replyStates.keys.any((id) => !agents.contains(id)))
      throw ArgumentError('只能控制当前群聊中 AI 成员的接话');
    var replyBefore = (runtime['replyBefore'] as Map? ?? const {})
        .cast<String, Object?>();
    if (replyStates.isNotEmpty && replyBefore.isEmpty) {
      final paused = await txn.query(
        'group_participation',
        where: 'conversation_id = ?',
        whereArgs: [conversationId],
      );
      replyBefore = {
        for (final id in agents)
          id as String: paused.where((r) => r['sender_id'] == id).firstOrNull,
      };
    }
    final controls = txn.batch();
    if (output['releaseReplyControl'] == true) {
      for (final entry in replyBefore.entries) {
        final old = entry.value as Map?;
        controls.insert('group_participation', {
          'conversation_id': conversationId,
          'sender_id': entry.key,
          'paused': old?['paused'] ?? 0,
          'reason': old?['reason'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        change.replyStates[entry.key] = old?['paused'] != 1;
      }
      replyBefore = {};
    } else {
      for (final entry in replyStates.entries) {
        controls.insert('group_participation', {
          'conversation_id': conversationId,
          'sender_id': entry.key,
          'paused': entry.value ? 0 : 1,
          'reason': entry.value ? null : '小程序正在安排发言',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        change.replyStates[entry.key] = entry.value;
      }
    }
    await controls.commit(noResult: true);
    if (views.keys.any((id) => !memberIds.contains(id)))
      throw ArgumentError('私密视图接收人必须是当前群成员');
    final closeKeys = (output['closeKeys'] as List? ?? const []);
    final closing = [
      for (final entry in bindings.entries)
        if (closeKeys.contains((entry.value as Map)['key'])) entry.key,
    ];
    if (closing.isNotEmpty) {
      final cards = await txn.query(
        'messages',
        columns: ['id', 'interactive_json'],
        where: 'id IN (${List.filled(closing.length, '?').join(',')})',
        whereArgs: closing,
      );
      final batch = txn.batch();
      for (final row in cards) {
        final card = InteractiveMessage.fromJson(
          MiniappProgram.decode(row['interactive_json']),
        );
        final next = InteractiveMessage.fromJson({
          ...card.toJson(includeParticipants: true),
          'revision': card.revision + 1,
          'participation': {...card.participation, 'closed': true},
          'buttons': const <Object?>[],
          'body': '${card.body}\n\n本次操作已结束。',
        });
        change.cards[row['id'] as String] = next;
        batch.update(
          'messages',
          {
            'interactive_json': jsonEncode(
              next.toJson(includeParticipants: true),
            ),
          },
          where: 'id = ?',
          whereArgs: [row['id']],
        );
        bindings.remove(row['id']);
      }
      await batch.commit(noResult: true);
    }
    final batch = txn.batch();
    for (final raw in effects) {
      final effect = (raw as Map).cast<String, Object?>();
      final audience = (effect['audience'] as List?)?.cast<String>();
      if (audience != null &&
          (audience.isEmpty || audience.any((id) => !memberIds.contains(id)))) {
        throw ArgumentError('消息接收人必须是当前群成员');
      }
      final id = newMessageId();
      final definition = effect['card'] as Map?;
      final wakeAi = effect['wakeAi'] == true;
      if (wakeAi && audience == null) throw ArgumentError('触发 AI 回复需要明确接收人');
      final card = definition == null
          ? null
          : InteractiveMessage.fromDefinition({
              ...definition.cast<String, Object?>(),
              'revision': 0,
              'showStatistics': false,
              'buttons': [
                for (final button in definition['buttons'] as List)
                  {
                    ...(button as Map).cast<String, Object?>(),
                    'programEvent': effect['event'],
                  },
              ],
              'participation': {
                ...?definition['participation'] as Map?,
                if (audience != null) 'audience': audience,
                '_programMessage': messageId,
                if (wakeAi) '_programWake': true,
                'visibility': 'private',
                'summaryVisibility': 'private',
              },
            });
      card?.validateTransport(html: false);
      if (card != null) {
        if (effect['event'] is! String || audience == null)
          throw ArgumentError('行动卡需要事件和明确的接收人');
        if (card.buttons.any((b) => b['notifyAi'] == true))
          throw ArgumentError('行动卡回调由小程序处理');
        bindings[id] = {
          'key': effect['key'],
          'action': effect['event'],
          'data': effect['data'],
          'actors': audience,
        };
      }
      final metadata =
          card ??
          (wakeAi
              ? InteractiveMessage(
                  revision: 0,
                  title: effect['text'] as String,
                  body: '',
                  buttons: const [],
                  participation: {
                    'audience': audience,
                    'presentation': 'message',
                    '_programWake': true,
                  },
                )
              : null);
      final message = AgentMessage(
        id: id,
        role: AgentMessageRole.user,
        senderId: MessageSender.localUser.id,
        text: effect['text'] as String? ?? card!.title,
        interactive: metadata,
        audience: audience,
        isSystem: card == null,
        isGroupMessage: true,
        createdAt: DateTime.now(),
      );
      batch.insert('messages', messageRow(conversationId, message));
      change.messages.add((message: message, wakeAi: wakeAi));
    }
    await batch.commit(noResult: true);
    final view = (output['view'] as Map).cast<String, Object?>();
    final wakeAt = output['wakeAt'] as int?;
    if (wakeAt != null && wakeAt <= now) throw ArgumentError('定时回调必须晚于当前时间');
    final next = {
      'state': output['state'],
      'privateViews': views,
      'bindings': bindings,
      'wakeAt': wakeAt,
      'replyBefore': replyBefore,
      'conversationId': conversationId,
      'messageId': messageId,
    };
    if (utf8.encode(jsonEncode(next)).length > 262144)
      throw ArgumentError('小程序状态最多 256 KB');
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
    if (effects.isNotEmpty) {
      final last = change.messages.last.message;
      await txn.rawUpdate(
        'UPDATE conversations SET message_count = message_count + ?, preview = ?, updated_at = ? WHERE id = ?',
        [
          effects.length,
          last.canView(MessageSender.localUser.id) ? last.text : '私密交互消息',
          last.createdAt.microsecondsSinceEpoch,
          conversationId,
        ],
      );
    }
    return change;
  }

  Future<void> tick() async {
    Map<String, Object?>? due;
    try {
      final change = await database.transaction((txn) async {
        final rows = await txn.query(
          'app_state',
          columns: ['value'],
          where:
              "key LIKE 'miniapp-program:%' AND json_extract(value, '\$.wakeAt') <= ? AND json_extract(value, '\$.messageId') IN (SELECT id FROM messages WHERE kind = 'html_game')",
          whereArgs: [DateTime.now().millisecondsSinceEpoch],
          orderBy: "json_extract(value, '\$.wakeAt')",
          limit: 1,
        );
        if (rows.isEmpty) return null;
        final runtime = MiniappProgram.decode(rows.single['value']);
        due = runtime;
        return reduce(
          txn,
          runtime['conversationId'] as String,
          runtime['messageId'] as String,
          'system:timer',
          eventId: 'timer:${runtime['messageId']}:${runtime['wakeAt']}',
          action: 'timer',
        );
      });
      change?.publish();
    } on Object catch (error) {
      if (due != null) {
        await database.update(
          'app_state',
          {
            'value': jsonEncode({
              ...due!,
              'wakeAt': null,
              'error': error.toString(),
            }),
          },
          where: 'key = ? AND json_extract(value, \'\$.wakeAt\') = ?',
          whereArgs: [
            MiniappProgram.key(due!['messageId'] as String),
            due!['wakeAt'],
          ],
        );
      }
      rethrow;
    }
  }

  Future<int?> nextWake() async {
    final rows = await database.query(
      'app_state',
      columns: ["json_extract(value, '\$.wakeAt') AS wake"],
      where:
          "key LIKE 'miniapp-program:%' AND json_extract(value, '\$.wakeAt') IS NOT NULL AND json_extract(value, '\$.messageId') IN (SELECT id FROM messages WHERE kind = 'html_game')",
      orderBy: "json_extract(value, '\$.wakeAt')",
      limit: 1,
    );
    return rows.firstOrNull?['wake'] as int?;
  }
}
