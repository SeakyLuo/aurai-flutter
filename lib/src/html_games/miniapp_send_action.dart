import 'dart:convert';
import 'dart:math';

/// Declarative send-time initialization; no page or AI execution is required.
Map<String, Object?> miniappSendAction(String html) {
  final match = RegExp(
    r'<script\s+type="application/json"\s+id="aurai-send-action">([\s\S]*?)</script>',
  ).firstMatch(html);
  if (match == null) return {};
  return (jsonDecode(match.group(1)!) as Map).cast<String, Object?>();
}

Map<String, Object?> initializeMiniappMessage(String html) {
  final action = miniappSendAction(html);
  if (action.isEmpty) return {};
  final choices = action['choices'];
  if (action['type'] != 'random-choice' ||
      choices is! List ||
      choices.isEmpty ||
      choices.length > 100 ||
      choices.any((value) => value is! String || value.length > 100)) {
    throw ArgumentError('小程序发送配置无效');
  }
  return {
    '_auraiFixedResult': true,
    'result': choices[Random.secure().nextInt(choices.length)],
    'revealAt': DateTime.now().millisecondsSinceEpoch + 900,
  };
}
