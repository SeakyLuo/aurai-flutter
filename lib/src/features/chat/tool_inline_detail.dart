import 'dart:convert';

String? toolInlineDetail(
  String? name,
  String? requestJson,
  String? resultJson,
) {
  final request = requestJson == null
      ? const <String, Object?>{}
      : jsonDecode(requestJson) as Map;
  final result = resultJson == null
      ? const <String, Object?>{}
      : jsonDecode(resultJson) as Map;
  final value = switch (name) {
    'shell' => request['command'],
    'searchWeb' ||
    'searchImages' ||
    'searchTools' ||
    'findApps' ||
    'searchConversations' ||
    'searchMessages' => request['query'],
    'readWebPage' => Uri.tryParse(
      (result['url'] ?? request['url']) as String? ?? '',
    )?.host,
    'readSkill' ||
    'runSkill' ||
    'createSkill' ||
    'updateSkill' ||
    'deleteSkill' => request['name'],
    'executeAndroidScript' => request['purpose'],
    'createScheduledTask' || 'updateScheduledTask' => request['title'],
    'inputUiText' => request['text'],
    'clickUiElement' => result['targetLabel'],
    'launchApp' => result['appName'],
    'dnsLookup' || 'tlsProbe' => request['host'],
    'httpProbe' => request['url'],
    'inspectAndroidApi' => request['className'],
    'sendNotification' => request['title'],
    _ => null,
  };
  if (value is! String || value.isEmpty) return null;
  return value.replaceAll(RegExp(r'[\r\n\t]+'), ' ');
}
