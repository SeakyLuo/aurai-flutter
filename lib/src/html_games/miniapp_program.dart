import 'dart:convert';

/// The reducer runs in the host, independently of the visible document.
abstract final class MiniappProgram {
  static final _pattern = RegExp(
    r'<script\s+type="application/aurai-program">([\s\S]*?)</script>',
  );

  static String? source(String html) => _pattern.firstMatch(html)?.group(1);
  static String document(String html) => html.replaceAll(_pattern, '');
  static String key(String messageId) => 'miniapp-program:$messageId';
  static Map<String, Object?> initial() => {
    'state': <String, Object?>{},
    'privateViews': <String, Object?>{},
    'bindings': <String, Object?>{},
    'wakeAt': null,
  };

  static Map<String, Object?> decode(Object? value) =>
      (jsonDecode(value as String) as Map).cast<String, Object?>();
}
