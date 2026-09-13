import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryStore {
  final _preferences = SharedPreferencesAsync();
  static const _key = 'conversation_search_history';
  Future<void> _pending = Future.value();
  Future<List<String>> read() async =>
      await _preferences.getStringList(_key) ?? [];
  Future<void> save(List<String> values) {
    final snapshot = List<String>.of(values);
    final write = _pending.then(
      (_) => _preferences.setStringList(_key, snapshot),
    );
    _pending = write.catchError((Object error) {});
    return write;
  }
}
