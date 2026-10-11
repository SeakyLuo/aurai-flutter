import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../domain/agent_models.dart';
import '../domain/message_sender.dart';
import 'html_app_store.dart';
import 'html_game.dart';
import 'html_game_session.dart';
import 'html_store.dart';
import 'miniapp_capability_protocol.dart';
import 'miniapp_library_store.dart';
import 'miniapp_program.dart';
import 'miniapp_program_runner.dart';
import 'miniapp_program_store.dart';

/// One rules engine serves chat cards and persisted, conversation-free games.
class BoardGameService {
  BoardGameService(this.database, this.game, {required this.independent});
  final Database database;
  final HtmlGame game;
  final bool independent;
  static Future<bool> supports(DatabaseExecutor db, String id) async {
    final rows = await db.query(
      'miniapp_installations',
      columns: ['source_id'],
      where: 'app_id = ? AND owner_id = ?',
      whereArgs: [id, MessageSender.localUser.id],
    );
    return const [
      'builtin.xiangqi',
      'builtin.gomoku',
      'builtin.tictactoe',
      'builtin.reversi',
      'builtin.connect4',
      'builtin.halma',
      'builtin.doudizhu',
      'builtin.uno',
      'builtin.scout',
      'builtin.battleship',
      'builtin.junqi',
      'builtin.azul',
    ].contains(rows.isEmpty ? id : rows.single['source_id']);
  }

  static final _jobs = <String, String>{};
  String? _ownedJob;
  void pause() {
    if (_jobs[_key] == _ownedJob) _jobs.remove(_key);
  }

  String get _key =>
      independent ? 'board:${game.appId}' : 'board:${game.messageId}';
  static String runtimeKey(String appId) => 'board-runtime:$appId';

  static Future<Map<String, Object?>> independentView(
    DatabaseExecutor db,
    Map<String, Object?> app,
  ) async {
    final (users, saved) = await (
      db.query(
        'message_senders',
        columns: ['id', 'name', 'kind'],
        where: 'id = ?',
        whereArgs: [MessageSender.localUser.id],
      ),
      db.query(
        'app_state',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [runtimeKey(app['id'] as String)],
      ),
    ).wait;
    final runtime = saved.isEmpty
        ? MiniappProgram.initial()
        : MiniappProgram.decode(saved.single['value']);
    return {
      ...MiniappProgram.decode(app['state_json']),
      '_miniapp': {
        'independent': true,
        'viewerId': MessageSender.localUser.id,
        'ownerId': MessageSender.localUser.id,
        'members': users,
        'own': (runtime['privateViews'] as Map)[MessageSender.localUser.id],
      },
    };
  }

  Future<HtmlGame> _load() => independent
      ? MiniappLibraryStore(database).loadIndependent(game.appId!)
      : HtmlStore(database).load(game.conversationId, game.messageId);

  void cancel() => _jobs.remove(_key);

  Future<Map<String, Object?>> handle(Map<String, Object?> args) async {
    if (game.appId == null || !await supports(database, game.appId!)) {
      throw StateError('此小程序不支持棋类对局');
    }
    switch (args['operation']) {
      case 'begin':
        final current = await _load();
        final view = current.state;
        final players = (view['players'] as List).cast<Map>();
        final human = players.firstWhere((p) => p['kind'] != 'engine');
        if (human['id'] != MessageSender.localUser.id) {
          throw StateError('只有对局玩家可以请求落子');
        }
        if (view['phase'] != 'playing' ||
            (!players.any(
                  (p) => p['kind'] == 'engine' && p['side'] == view['turn'],
                ) &&
                view['drawOffer'] != human['id'])) {
          return {'skipped': true};
        }
        final token = newMessageId();
        _ownedJob = token;
        _jobs[_key] = token;
        return {'token': token, 'version': current.version, 'view': view};
      case 'complete':
        final result = (args['event'] as Map).cast<String, Object?>();
        if (_jobs[_key] != result['token']) return {'cancelled': true};
        final current = await _load();
        if (_jobs[_key] != result['token']) return {'cancelled': true};
        _jobs.remove(_key);
        if (current.version != result['version']) return {'stale': true};
        final action = result['action'];
        final cardGame = const [
          'doudizhu',
          'uno',
          'scout',
          'battleship',
          'junqi',
          'azul',
        ].contains(current.state['gameType']);
        if (cardGame
            ? action != 'cardAi'
            : action != 'move' && action != 'answerDraw') {
          throw ArgumentError('不支持的引擎操作');
        }
        await _event(
          {'eventId': newMessageId(), 'action': action, 'data': result['data']},
          current.version,
          decision: true,
        );
        return {'accepted': true};
      case 'event':
        cancel();
        final current = await _load();
        await _event(
          (args['event'] as Map).cast<String, Object?>(),
          current.version,
        );
        return {'accepted': true};
      default:
        throw ArgumentError('不支持的棋局操作');
    }
  }

  Future<void> _event(
    Map<String, Object?> event,
    int version, {
    bool decision = false,
  }) async {
    if (!independent) {
      await MiniappProgramStore(database).event(
        game.conversationId,
        game.messageId,
        MessageSender.localUser.id,
        {...event, 'expectedVersion': version},
        decision: decision,
      );
      return;
    }
    await database.transaction((txn) async {
      final app = await HtmlAppStore.load(txn, game.appId!);
      if (app['version'] != version) throw StateError('棋盘已变化，请重新操作');
      final saved = await txn.query(
        'app_state',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [runtimeKey(game.appId!)],
      );
      final runtime = saved.isEmpty
          ? MiniappProgram.initial()
          : MiniappProgram.decode(saved.single['value']);
      final members = await txn.query(
        'message_senders',
        columns: ['id', 'name', 'kind'],
        where: 'id = ?',
        whereArgs: [MessageSender.localUser.id],
      );
      final code = await HtmlAppStore.code(app);
      final output = await const PlatformMiniappProgramRunner().run(
        MiniappCapabilityProtocol.wrap(MiniappProgram.source(code)!, {
          'messages.send',
          'replies.interrupt',
        }),
        {
          'state': runtime['state'],
          'decision': decision,
          'event': {...event, 'actorId': MessageSender.localUser.id},
          'members': members,
          'ownerId': MessageSender.localUser.id,
        },
      );
      await txn.insert('app_state', {
        'key': runtimeKey(game.appId!),
        'value': jsonEncode({
          'state': output['state'],
          'privateViews': output['privateViews'],
        }),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.update(
        'html_apps',
        {
          'state_json': jsonEncode(output['view']),
          'version': version + 1,
          'updated_at': DateTime.now().microsecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [game.appId],
      );
    });
    HtmlGameSignals.appChanges.add(game.appId!);
  }
}
