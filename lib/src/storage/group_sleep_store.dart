import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class GroupSleepStore {
  final _preferences = SharedPreferencesAsync();
  static const _key = 'group_member_sleeps';
  final _groups = <String, Map<String, int>>{};
  Future<void> _writes = Future.value();
  Timer? _timer;
  bool _disposed = false;
  late Future<void> Function(String groupId, Set<String> members) _wake;

  Future<void> initialize(
    Future<void> Function(String groupId, Set<String> members) wake,
  ) async {
    _wake = wake;
    final saved = await _preferences.getString(_key);
    if (saved != null) {
      final data = jsonDecode(saved) as Map<String, dynamic>;
      for (final entry in data.entries) {
        _groups[entry.key] = (entry.value as Map).cast<String, int>();
      }
    }
    _arm();
  }

  Map<String, DateTime> forGroup(String id) => {
    for (final entry in (_groups[id] ?? const <String, int>{}).entries)
      entry.key: DateTime.fromMillisecondsSinceEpoch(entry.value),
  };

  Future<void> save(String group, String member, DateTime until) => _edit(() {
    _groups.putIfAbsent(group, () => {})[member] = until.millisecondsSinceEpoch;
  });

  Future<void> remove(String group, [String? member]) => _edit(() {
    if (member == null) {
      _groups.remove(group);
    } else {
      _groups[group]?.remove(member);
      if (_groups[group]?.isEmpty == true) _groups.remove(group);
    }
  });

  Future<void> retain(String group, Set<String> members) => _edit(() {
    _groups[group]?.removeWhere((id, _) => !members.contains(id));
    if (_groups[group]?.isEmpty == true) _groups.remove(group);
  });

  Future<void> _edit(void Function() edit) {
    final next = _writes.then((_) async {
      final before = jsonEncode(_groups);
      edit();
      try {
        await _preferences.setString(_key, jsonEncode(_groups));
      } on Object {
        _groups.clear();
        for (final entry in (jsonDecode(before) as Map).entries) {
          _groups[entry.key as String] = (entry.value as Map)
              .cast<String, int>();
        }
        rethrow;
      } finally {
        _arm();
      }
    });
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

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }
}
