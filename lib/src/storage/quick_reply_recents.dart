import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';

abstract final class QuickReplyRecents {
  static final _preferences = SharedPreferencesAsync();
  static const _key = 'quick_reply_recents';
  static Future<void> _writing = Future.value();

  static Future<List<String>> load() async {
    await _writing;
    return await _preferences.getStringList(_key) ?? const [];
  }

  static void record(String key) {
    _writing = _writing
        .then((_) async {
          final previous = await _preferences.getStringList(_key) ?? const [];
          await _preferences.setStringList(_key, [
            key,
            ...previous.where((value) => value != key).take(4),
          ]);
        })
        .catchError((Object error, StackTrace stack) {
          developer.log(
            'Unable to save recent reactions',
            error: error,
            stackTrace: stack,
          );
        });
  }
}
