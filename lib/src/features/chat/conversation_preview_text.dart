import 'package:flutter/material.dart';
import '../../app/global_ui.dart';
import 'conversation.dart';

class ConversationPreviewText extends StatelessWidget {
  const ConversationPreviewText({
    super.key,
    required this.conversation,
    this.emptyText = '',
  });
  final Conversation conversation;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final draft = conversation.draftPreview;
    return Text.rich(
      TextSpan(
        children: [
          if (draft != null)
            TextSpan(
              text: '[草稿] ',
              style: TextStyle(
                color: theme.brightness == Brightness.dark
                    ? GlobalUI.primary
                    : GlobalUI.onPrimaryBackground,
              ),
            ),
          TextSpan(text: draft ?? conversation.preview ?? emptyText),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
    );
  }
}
