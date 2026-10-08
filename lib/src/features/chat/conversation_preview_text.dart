import 'package:flutter/material.dart';
import '../../domain/message_summary.dart';
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
    this.showRunning = false,
  });
  final Conversation conversation;
  final String emptyText;
  final int maxLines;
  final String prefix;
  final bool showFailure;
  final bool showRunning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final question = conversation.questionPreview;
    final draft = question == null ? conversation.draftPreview : null;
    final running =
        showRunning &&
        (conversation.runState == ChatRunState.running ||
            conversation.runState == ChatRunState.stopping);
    final text = MessagePreviewText(
      text: MessageSummary.preview(
        question ?? draft ?? conversation.preview ?? emptyText,
      ),
      literal: draft != null || question != null,
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
      textWidthBasis: running
          ? TextWidthBasis.longestLine
          : TextWidthBasis.parent,
      style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
    );
    final failure =
        showFailure && ConversationStatusDot.needsAttention(conversation);
    if (!running && !failure) {
      return text;
    }
    return Row(
      children: [
        if (running) ...[
          Flexible(child: text),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Semantics(
              label: 'AI 正在执行',
              child: SizedBox.square(
                dimension: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.65,
                  strokeCap: StrokeCap.round,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ] else ...[
          Expanded(child: text),
          ConversationStatusDot(conversation: conversation),
        ],
      ],
    );
  }
}
