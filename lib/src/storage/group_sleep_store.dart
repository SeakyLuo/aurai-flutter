import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GroupSleepStore extends ChangeNotifier {
  final _preferences = SharedPreferencesAsync();
  late Database _database;
  static const _key = 'group_member_sleeps';
  final _groups = <String, Map<String, int>>{};
  Future<void> _writes = Future.value();
  Timer? _timer;
  bool _disposed = false;
  late Future<void> Function(String groupId, Set<String> members) _wake;

  Future<void> initialize(
    Database database,
    Future<void> Function(String groupId, Set<String> members) wake,
  ) async {
    _database = database;
    _wake = wake;
    final legacy = await _preferences.getString(_key);
    if (legacy != null) {
      await database.insert('app_state', {
        'key': _key,
        'value': legacy,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await _preferences.remove(_key);
    }
    await reload();
  }

  Future<void> reload() => _enqueue(() async {
    final rows = await _database.query(
      'app_state',
      where: 'key = ?',
      whereArgs: [_key],
    );
    _groups
      ..clear()
      ..addAll(_decode(rows.isEmpty ? '{}' : rows.single['value'] as String));
    _arm();
    notifyListeners();
  });

  Map<String, Map<String, int>> _decode(String encoded) => {
    for (final entry in (jsonDecode(encoded) as Map).entries)
      entry.key as String: (entry.value as Map).cast<String, int>(),
  };

  static Future<void> removeIn(
    DatabaseExecutor txn,
    String group,
    String member,
  ) async {
    final rows = await txn.query(
      'app_state',
      where: 'key = ?',
      whereArgs: [_key],
    );
    if (rows.isEmpty) return;
    final groups = jsonDecode(rows.single['value'] as String) as Map;
    final members = groups[group] as Map?;
    if (members == null) return;
    members.remove(member);
    if (members.isEmpty) groups.remove(group);
    await txn.update(
      'app_state',
      {'value': jsonEncode(groups)},
      where: 'key = ?',
      whereArgs: [_key],
    );
  }

  Map<String, DateTime> forGroup(String id) => {
    for (final entry in (_groups[id] ?? const <String, int>{}).entries)
      entry.key: DateTime.fromMillisecondsSinceEpoch(entry.value),
  };

  Future<void> save(String group, String member, DateTime until) => _edit((
    groups,
  ) {
    groups.putIfAbsent(group, () => {})[member] = until.millisecondsSinceEpoch;
  });

  Future<void> remove(String group, [String? member]) => _edit((groups) {
    if (member == null) {
      groups.remove(group);
    } else {
      groups[group]?.remove(member);
      if (groups[group]?.isEmpty == true) groups.remove(group);
    }
  });

  Future<void> saveMembers(String group, Set<String> members, DateTime until) =>
      _edit((groups) {
        final sleepers = groups.putIfAbsent(group, () => {});
        for (final member in members) {
          sleepers[member] = until.millisecondsSinceEpoch;
        }
      });

  Future<void> wakeMembers(
    String group,
    Set<String> members, {
    required bool immediate,
  }) => _edit((groups) {
    final sleepers = groups[group];
    if (sleepers == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final member in members) {
      if (immediate) {
        sleepers.remove(member);
      } else if (sleepers.containsKey(member)) {
        sleepers[member] = now;
      }
    }
    if (sleepers.isEmpty) groups.remove(group);
  });

  Future<void> retain(String group, Set<String> members) => _edit((groups) {
    groups[group]?.removeWhere((id, _) => !members.contains(id));
    if (groups[group]?.isEmpty == true) groups.remove(group);
  });

  Future<void> _edit(void Function(Map<String, Map<String, int>>) edit) =>
      _enqueue(() async {
        final next = await _database.transaction((txn) async {
          final rows = await txn.query(
            'app_state',
            where: 'key = ?',
            whereArgs: [_key],
          );
          final groups = _decode(
            rows.isEmpty ? '{}' : rows.single['value'] as String,
          );
          edit(groups);
          await txn.insert('app_state', {
            'key': _key,
            'value': jsonEncode(groups),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          return groups;
        });
        _groups
          ..clear()
          ..addAll(next);
        _arm();
        notifyListeners();
      });

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _writes.then((_) => action());
    _writes = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  void _arm() {
    if (_disposed) return;
    _timer?.cancel();
    final times = _groups.values.expand((m) => m.values);
    if (times.isEmpty) return;
    final earliest = times.reduce((a, b) => a < b ? a : b);
    final delay = earliest - DateTime.now().millisecondsSinceEpoch;
    _timer = Timer(Duration(milliseconds: delay > 0 ? delay : 1000), _check);
  }

  Future<void> _check() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final due = _groups.entries.where(
      (g) => g.value.values.any((at) => at <= now),
    );
    if (due.isEmpty) {
      _arm();
      return;
    }
    final group = due.first;
    try {
      await _wake(group.key, {
        for (final entry in group.value.entries)
          if (entry.value <= now) entry.key,
      });
    } finally {
      // Busy conversations retry later without spinning or querying storage.
      _timer?.cancel();
      if (!_disposed) {
        final overdue = _groups.values
            .expand((m) => m.values)
            .any((at) => at <= DateTime.now().millisecondsSinceEpoch);
        if (overdue) {
          _timer = Timer(const Duration(seconds: 30), _check);
        } else {
          _arm();
        }
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
    _disposed = true;
    _timer?.cancel();
  }
}
