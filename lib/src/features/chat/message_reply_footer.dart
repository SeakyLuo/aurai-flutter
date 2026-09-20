import 'package:flutter/material.dart';
import '../../domain/source_reference.dart';
import 'copy_icon.dart';
import 'message_star_button.dart';
import 'message_quote_view.dart';
import 'message_time.dart';
import 'source_citation_view.dart';

class MessageReplyFooter extends StatelessWidget {
  const MessageReplyFooter({
    super.key,
    required this.copied,
    required this.messageId,
    required this.onCopy,
    required this.createdAt,
    required this.sources,
    required this.onOpenLink,
    this.onQuote,
    this.onMore,
  });

  final bool copied;
  final String messageId;
  final VoidCallback onCopy;
  final VoidCallback? onQuote;
  final VoidCallback? onMore;
  final DateTime createdAt;
  final List<SourceReference> sources;
  final ValueChanged<String?> onOpenLink;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 0, 18, 20),
    child: Row(
      children: [
        IconButton(
          tooltip: copied ? '已复制' : '复制回复',
          onPressed: onCopy,
          icon: CopyIcon(copied: copied),
          style: IconButton.styleFrom(
            fixedSize: const Size.square(32),
            minimumSize: const Size.square(32),
            padding: const EdgeInsets.all(4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          visualDensity: VisualDensity.compact,
        ),
        MessageStarButton(messageId: messageId),
        if (onMore != null)
          IconButton(
            tooltip: '更多',
            onPressed: onMore,
            icon: const Icon(Icons.more_horiz_rounded, size: 24),
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              fixedSize: const Size.square(32),
              minimumSize: const Size.square(32),
              padding: const EdgeInsets.all(4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        if (onQuote != null)
          IconButton(
            tooltip: '引用',
            onPressed: onQuote,
            icon: const QuoteIcon(),
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              fixedSize: const Size.square(32),
              minimumSize: const Size.square(32),
              padding: const EdgeInsets.all(4),
            ),
          ),
        const SizedBox(width: 6),
        Tooltip(
          message: messageTime(createdAt),
          triggerMode: TooltipTriggerMode.tap,
          child: Text(
            messageTime(createdAt),
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
        if (sources.isNotEmpty) ...[
          const Spacer(),
          MessageSourcesButton(sources: sources, onOpenLink: onOpenLink),
        ],
      ],
    ),
  );
}
