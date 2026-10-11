import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'board_game_service.dart';
import 'miniapp_program.dart';

/// Upgrade saved opponents when the bundled board-game code changes.
/// Board positions, move history and chat messages remain intact.
Future<void> upgradeBoardGame(DatabaseExecutor db, String appId) async {
  if (appId != 'builtin.xiangqi' && appId != 'builtin.gomoku') return;
  final (apps, games, runtimes) = await (
    db.query(
      'html_apps',
      columns: ['state_json'],
      where: 'id = ?',
      whereArgs: [appId],
    ),
    db.query(
      'html_games',
      columns: ['message_id', 'state_json', 'version'],
      where: 'app_id = ?',
      whereArgs: [appId],
    ),
    db.query(
      'app_state',
      columns: ['key', 'value'],
      where:
          "key = ? OR key IN (SELECT 'miniapp-program:' || message_id FROM html_games WHERE app_id = ?)",
      whereArgs: [BoardGameService.runtimeKey(appId), appId],
    ),
  ).wait;
  final batch = db.batch();
  for (final row in apps) {
    final state = MiniappProgram.decode(row['state_json']);
    _upgrade(state);
    batch.update(
      'html_apps',
      {'state_json': jsonEncode(state)},
      where: 'id = ?',
      whereArgs: [appId],
    );
  }
  for (final row in games) {
    final state = MiniappProgram.decode(row['state_json']);
    _upgrade(state);
    batch.update(
      'html_games',
      {
        'state_json': jsonEncode(state),
        'version': (row['version'] as int) + 1,
        'preview': null,
      },
      where: 'message_id = ?',
      whereArgs: [row['message_id']],
    );
  }
  for (final row in runtimes) {
    final runtime = MiniappProgram.decode(row['value']);
    _upgrade((runtime['state'] as Map).cast<String, Object?>());
    // Human history previews store actor IDs as well as the canonical history.
    for (final view in (runtime['privateViews'] as Map).values) {
      if ((view as Map)['history'] case final List history) _history(history);
    }
    batch.update(
      'app_state',
      {'value': jsonEncode(runtime)},
      where: 'key = ?',
      whereArgs: [row['key']],
    );
  }
  await batch.commit(noResult: true);
}

void _upgrade(Map<String, Object?> state) {
  if (state['players'] case final List players) {
    state.putIfAbsent('difficulty', () => 3);
    for (final player in players.cast<Map>()) {
      if (player['kind'] == 'decision') {
        player['kind'] = 'engine';
        player['id'] = 'engine:local';
        player['name'] = '本地 AI';
      }
    }
    if (state['drawOffer'] == 'decision:default')
      state['drawOffer'] = 'engine:local';
    if (state['history'] case final List history) _history(history);
  }
}

void _history(List history) {
  for (final move in history.cast<Map>()) {
    if (move['actorId'] == 'decision:default') move['actorId'] = 'engine:local';
  }
}
