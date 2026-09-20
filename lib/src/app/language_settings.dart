import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PreferredLanguage {
  simplifiedChinese('简体中文'),
  traditionalChinese('繁體中文'),
  english('English'),
  japanese('日本語'),
  korean('한국어'),
  french('Français'),
  german('Deutsch'),
  spanish('Español');

  const PreferredLanguage(this.label);
  final String label;
}

class LanguageSettings extends ChangeNotifier {
  LanguageSettings._();
  static final instance = LanguageSettings._();
  final _preferences = SharedPreferencesAsync();
  PreferredLanguage _language = PreferredLanguage.simplifiedChinese;
  PreferredLanguage get language => _language;

  String get instructions =>
      '用户的偏好语言是${_language.label}。请使用该语言思考和回复，包括工具调用前后的思考；'
      '代码、网址、参数名和专有名词保留原文。用户当前明确指定其他语言或要求翻译时，以当前要求为准。';

  Future<void> load() async {
    final saved = await _preferences.getString('preferred_language');
    if (saved != null) _language = PreferredLanguage.values.byName(saved);
  }

  Future<void> setLanguage(PreferredLanguage language) async {
    await _preferences.setString('preferred_language', language.name);
    _language = language;
    notifyListeners();
  }
}
