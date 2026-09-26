import '../../storage/group_message_search.dart';
import 'markdown_preview_text.dart';

String groupSavedMessagePreview(GroupMessageSearchResult message) {
  if (message.html case final app?) return '[小程序] ${app.title}';
  if (message.interactive case final card?) return card.title;
  return [
    if (message.text.trim().isNotEmpty) markdownPreviewText(message.text),
    if (message.images.isNotEmpty) '[图片]',
    for (final file in message.files) '[文件] ${file.name}',
  ].join(' ');
}
