import 'agent_models.dart';
import 'message_sender.dart';

/// Shared content labels for saved list previews and live message previews.
abstract final class MessageSummary {
  static String attachment({
    required String kind,
    required String mimeType,
    String? name,
  }) {
    if (kind == 'image' || mimeType.startsWith('image/')) return '[图片]';
    if (mimeType.startsWith('video/')) return '[视频]';
    if (mimeType.startsWith('audio/')) return '[音频]';
    if (mimeType == 'text/html' || mimeType == 'application/xhtml+xml') {
      return '[小程序] ${htmlFileTitle(name!)}';
    }
    return '[文件] $name';
  }

  static String htmlFileTitle(String name) =>
      name.replaceFirst(RegExp(r'\.x?html?$', caseSensitive: false), '');

  static String content({
    required String text,
    Iterable<String> attachments = const [],
    String? htmlTitle,
    String? interactiveTitle,
  }) {
    final labels = attachments.toSet();
    final htmlFiles = labels
        .where((label) => label.startsWith('[小程序] '))
        .toList();
    var body = text;
    if (htmlTitle == null && htmlFiles.length == 1) {
      final title = htmlFiles.single.substring('[小程序] '.length);
      if (body == title) {
        body = '';
      } else if (body.startsWith('$title\n\n')) {
        body = body.substring(title.length).trimLeft();
      }
    }
    return [
      if (htmlTitle != null)
        '[小程序] $htmlTitle'
      else ...[
        ...htmlFiles,
        if (interactiveTitle != null)
          '[交互消息] ${body.isEmpty ? interactiveTitle : body}'
        else if (body.isNotEmpty)
          body,
      ],
      ...labels.where((label) => !htmlFiles.contains(label)),
    ].join(' ');
  }

  static String sender(
    String text, {
    required String senderId,
    required String senderName,
    bool isSystem = false,
  }) => isSystem || senderId == MessageSender.localUser.id
      ? text
      : '$senderName：$text';

  static String fromMessage(
    AgentMessage message, {
    bool withSender = false,
    bool includeAttachments = true,
  }) {
    if (message.interactive?.canView(MessageSender.localUser.id) == false) {
      return '';
    }
    final body = content(
      text: message.interactive == null
          ? message.text
          : '${message.interactive!.title}\n${message.interactive!.body}',
      htmlTitle: message.htmlGame?.title,
      interactiveTitle: message.interactive?.title,
      attachments: includeAttachments
          ? [
              if (message.images.isNotEmpty) '[图片]',
              for (final file in message.files)
                attachment(
                  kind: 'file',
                  mimeType: file.mimeType,
                  name: file.name,
                ),
            ]
          : const [],
    );
    return withSender && message.sender != null
        ? sender(
            body,
            senderId: message.senderId,
            senderName: message.sender!.name,
            isSystem: message.isSystem,
          )
        : body;
  }
}
