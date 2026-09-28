import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryStore {
  SearchHistoryStore({String? projectId})
    : _key = projectId == null
          ? 'conversation_search_history'
          : 'project_search_history:$projectId';

  final _preferences = SharedPreferencesAsync();
  final String _key;
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
