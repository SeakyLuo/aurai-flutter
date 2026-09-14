import 'package:flutter/material.dart';
import '../../app/global_ui.dart';
import 'conversation.dart';
import 'conversation_status_dot.dart';
import 'markdown_preview_text.dart';

class ConversationPreviewText extends StatelessWidget {
  const ConversationPreviewText({
    super.key,
    required this.conversation,
    this.emptyText = '',
    this.maxLines = 1,
    this.prefix = '',
    this.showUnread = false,
  });
  final Conversation conversation;
  final String emptyText;
  final int maxLines;
  final String prefix;
  final bool showUnread;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final draft = conversation.draftPreview;
    final text = Text.rich(
      TextSpan(
        children: [
          if (prefix.isNotEmpty) TextSpan(text: prefix),
          if (draft != null)
            TextSpan(
              text: '[草稿] ',
              style: TextStyle(
                color: theme.brightness == Brightness.dark
                    ? GlobalUI.primary
                    : GlobalUI.onPrimaryBackground,
              ),
            ),
          TextSpan(
            text:
                draft ?? markdownPreviewText(conversation.preview ?? emptyText),
          ),
        ],
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
    );
    if (!showUnread ||
        !ConversationStatusDot.hasUnreadCompletion(conversation)) {
      return text;
    }
    return Row(
      children: [
        Flexible(child: text),
        ConversationStatusDot(conversation: conversation),
      ],
    );
  }
}
