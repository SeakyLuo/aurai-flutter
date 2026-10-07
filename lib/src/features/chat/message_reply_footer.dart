import 'package:flutter/material.dart';
import '../../domain/source_reference.dart';
import 'copy_icon.dart';
import 'speech_readout_button.dart';
import 'message_quote_view.dart';
import 'message_time.dart';
import 'source_citation_view.dart';
import 'settings_icon.dart';

class MessageReplyFooter extends StatelessWidget {
  const MessageReplyFooter({
    super.key,
    required this.copied,
    required this.messageKey,
    required this.onCopy,
    required this.createdAt,
    required this.sources,
    required this.onOpenLink,
    this.onQuote,
    this.onMore,
    this.onReadAloud,
    this.goalElapsed,
  });

  final bool copied;
  final Object messageKey;
  final VoidCallback onCopy;
  final VoidCallback? onQuote;
  final VoidCallback? onMore;
  final VoidCallback? onReadAloud;
  final DateTime createdAt;
  final List<SourceReference> sources;
  final ValueChanged<String?> onOpenLink;
  final Duration? goalElapsed;

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
        if (onReadAloud != null)
          SpeechReadoutButton(messageKey: messageKey, onPressed: onReadAloud!),
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
        const SizedBox(width: 6),
        Flexible(
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (goalElapsed case final elapsed?)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox.square(
                      dimension: 16,
                      child: SettingsIcon(type: SettingsIconType.selectCircle),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Goal achieved in ${_goalDuration(elapsed)}',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
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
            ],
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

String _goalDuration(Duration elapsed) => [
  if (elapsed.inHours > 0) '${elapsed.inHours}h',
  if (elapsed.inMinutes.remainder(60) > 0)
    '${elapsed.inMinutes.remainder(60)}m',
  '${elapsed.inSeconds.remainder(60)}s',
].join(' ');
