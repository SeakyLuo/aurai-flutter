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
    'askUser' => request['title'],
    'createTextFile' => request['fileName'],
    'deliverFile' => request['name'],
    'searchFiles' => request['query'],
    'shell' || 'executeShizuku' => request['command'],
    'searchWeb' ||
    'searchImages' ||
    'searchTools' ||
    'searchSkills' ||
    'findApps' ||
    'findContacts' ||
    'listFriends' ||
    'listAiContacts' ||
    'listGroupChats' ||
    'readGroupMessages' ||
    'listMemories' ||
    'listHtmlApps' ||
    'listHtmlAppPublications' => request['query'],
    'searchConversations' ||
    'searchMessages' => (request['keywords'] as List?)?.join('、'),
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
    'sendConversationMessage' => _messagePreview(request),
    'sendGroupMessage' => _messagePreview(request['message'] as Map?),
    'sendHtmlMessage' || 'sendInteractiveMessage' => request['title'],
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

// Message text has the same meaning for private sends and nested group sends.
// Show image counts, not local paths or internal message/recipient IDs.
String? _messagePreview(Map? message) {
  if (message == null) return null;
  final text = message['text'] as String?;
  final imageCount = (message['imagePaths'] as List? ?? const []).length;
  return [
    if (text != null && text.isNotEmpty) text,
    if (imageCount > 0) '图片 × $imageCount',
  ].join(' · ');
}
