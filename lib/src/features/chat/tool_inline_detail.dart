import 'dart:convert';

String? toolInlineDetail(
  String? name,
  String? requestJson,
  String? resultJson,
) {
  final request = requestJson == null
      ? const <String, Object?>{}
      : jsonDecode(requestJson) as Map;
  final needsResult = const {
    'readWebPage',
    'clickUiElement',
    'launchApp',
  }.contains(name);
  final result = !needsResult || resultJson == null
      ? const <String, Object?>{}
      : jsonDecode(resultJson) as Map;
  final value = switch (name) {
    'createTextFile' => request['fileName'],
    'searchFiles' => request['query'],
    'shell' || 'executeShizuku' => request['command'],
    'searchWeb' ||
    'searchImages' ||
    'searchTools' ||
    'searchSkills' ||
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
    'deleteSkill' ||
    'installSkill' ||
    'enableSkill' ||
    'disableSkill' ||
    'uninstallSkill' => request['name'],
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
