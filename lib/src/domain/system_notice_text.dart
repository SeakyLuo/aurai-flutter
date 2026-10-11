import 'interactive_message.dart';

InteractiveMessage? systemNoticeMetadata(String text) =>
    systemNoticeMemberPattern.hasMatch(text)
    ? InteractiveMessage.card(
        revision: 1,
        title: '',
        body: '',
        buttons: const [],
        participation: {'presentation': 'message', '_systemNoticeText': text},
      )
    : null;

String systemNoticeMember(String senderId, String name) {
  final label = name.replaceAllMapped(
    RegExp(r'[\\\[\]]'),
    (match) => '\\${match[0]}',
  );
  return '[$label](aurai://member/${Uri.encodeComponent(senderId)})';
}

final systemNoticeMemberPattern = RegExp(
  r'\[((?:\\.|[^\]])+)\]\(aurai://member/[^)]+\)',
);

String systemNoticePlainText(String text) => text.replaceAllMapped(
  systemNoticeMemberPattern,
  (match) => match[1]!.replaceAllMapped(RegExp(r'\\(.)'), (match) => match[1]!),
);
