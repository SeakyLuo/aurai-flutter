import '../../storage/group_message_search.dart';
import 'markdown_preview_text.dart';
import '../../domain/markdown_plain_text.dart';

String groupSavedMessagePreview(GroupMessageSearchResult message) {
  if (message.html case final app?) return '[小程序] ${app.title}';
  if (message.interactive case final card?) return card.title;
  return [
    if (message.text.trim().isNotEmpty)
      message.markdown
          ? markdownPreviewText(message.text)
          : memberMentionsPlainText(message.text),
    if (message.images.isNotEmpty) '[图片]',
    for (final file in message.files) '[文件] ${file.name}',
  ].join(' ');
}
