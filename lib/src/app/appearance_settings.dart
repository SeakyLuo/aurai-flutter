import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppearanceSettings extends ChangeNotifier {
  AppearanceSettings._();
  static final instance = AppearanceSettings._();
  final _preferences = SharedPreferencesAsync();
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;
  String get label => switch (_mode) {
    ThemeMode.system => '跟随系统',
    ThemeMode.light => '关闭',
    ThemeMode.dark => '开启',
  };

  Future<void> load() async {
    final saved = await _preferences.getString('theme_mode');
    if (saved != null) _mode = ThemeMode.values.byName(saved);
  }

  Future<void> setMode(ThemeMode mode) async {
    await _preferences.setString('theme_mode', mode.name);
    _mode = mode;
    notifyListeners();
  }
}
