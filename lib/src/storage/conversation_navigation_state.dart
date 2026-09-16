import 'package:shared_preferences/shared_preferences.dart';

class ConversationNavigationState {
  late SharedPreferences _preferences;
  bool detailVisible = false;
  Future<void> _write = Future.value();

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
    detailVisible =
        _preferences.getBool('conversation_detail_visible') ?? false;
  }

  Future<void> setDetailVisible(bool visible) {
    detailVisible = visible;
    final pending = _write.then((_) async {
      if (!await _preferences.setBool('conversation_detail_visible', visible)) {
        throw StateError('保存页面位置失败');
      }
    });
    _write = pending.catchError((Object _) {});
    return pending;
  }
}
