import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'miniapp_program.dart';

/// Timers dispatch through the same transactional event boundary as user actions.
class MiniappProgramScheduler {
  const MiniappProgramScheduler();

  Future<T?> tick<T>(
    Database database,
    Future<T> Function(DatabaseExecutor txn, Map<String, Object?> runtime)
    dispatch,
  ) async {
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
        return dispatch(txn, runtime);
      });
      return change;
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

  Future<int?> nextWake(Database database) async {
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
