import 'dart:convert';

import 'package:sqflite/sqflite.dart';

abstract final class AvatarSymbolRecents {
  static const _key = 'avatar_symbol_recents';

  static Future<List<String>> load(DatabaseExecutor database) async {
    final rows = await database.query(
      'app_state',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_key],
      limit: 1,
    );
    if (rows.isEmpty) return const [];
    return (jsonDecode(rows.single['value'] as String) as List).cast<String>();
  }

  static Future<List<String>> record(
    DatabaseExecutor database,
    String value,
  ) async {
    final previous = await load(database);
    final values = [
      value,
      ...previous.where((item) => item != value),
    ].take(22).toList();
    await database.insert('app_state', {
      'key': _key,
      'value': jsonEncode(values),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return values;
  }
}
