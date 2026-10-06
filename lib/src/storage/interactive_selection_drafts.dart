import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class InteractiveSelectionDrafts {
  static final instance = InteractiveSelectionDrafts();
  static const _prefix = 'interactive_selection_draft:';
  late SharedPreferences _preferences;
  final _values = <String, String>{};
  Future<void> _pending = Future.value();

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
    _values.clear();
    for (final key in _preferences.getKeys().where(
      (key) => key.startsWith(_prefix),
    )) {
      _values[key] = _preferences.getString(key)!;
    }
  }

  String _key(String messageId, String actorId, String buttonId) =>
      '$_prefix${jsonEncode([messageId, actorId, buttonId])}';

  Set<String>? read(
    String messageId,
    String actorId,
    String buttonId,
    String version,
  ) {
    final raw = _values[_key(messageId, actorId, buttonId)];
    if (raw == null) return null;
    final saved = jsonDecode(raw) as Map<String, dynamic>;
    return saved['version'] == version
        ? (saved['selected'] as List).cast<String>().toSet()
        : null;
  }

  Future<void> save(
    String messageId,
    String actorId,
    String buttonId,
    String version,
    Set<String> selected,
  ) {
    final key = _key(messageId, actorId, buttonId);
    final value = selected.isEmpty
        ? null
        : jsonEncode({'version': version, 'selected': selected.toList()});
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
    final previous = _pending;
    final done = Completer<void>();
    _pending = done.future;
    return (() async {
      await previous;
      try {
        final saved = value == null
            ? await _preferences.remove(key)
            : await _preferences.setString(key, value);
        if (!saved) throw StateError('保存投票草稿失败');
      } finally {
        done.complete();
      }
    })();
  }
}
