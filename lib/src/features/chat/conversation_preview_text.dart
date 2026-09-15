import 'package:flutter/material.dart';
import '../../app/global_ui.dart';
import 'conversation.dart';
import 'conversation_status_dot.dart';
import 'message_preview_text.dart';

class ConversationPreviewText extends StatelessWidget {
  const ConversationPreviewText({
    super.key,
    required this.conversation,
    this.emptyText = '',
    this.maxLines = 1,
    this.prefix = '',
    this.showFailure = false,
  });
  final Conversation conversation;
  final String emptyText;
  final int maxLines;
  final String prefix;
  final bool showFailure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final draft = conversation.draftPreview;
    final text = MessagePreviewText(
      text: draft ?? conversation.preview ?? emptyText,
      literal: draft != null,
      prefix: [
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
      ],
      maxLines: maxLines,
      style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
    );
    if (!showFailure ||
        conversation.kind == ConversationKind.group ||
        conversation.runState != ChatRunState.failed) {
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
