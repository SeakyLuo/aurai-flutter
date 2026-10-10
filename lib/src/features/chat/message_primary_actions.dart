import 'package:flutter/material.dart';
import 'attachment_action_icon.dart';
import 'copy_icon.dart';
import 'message_action.dart';
import 'message_quote_view.dart';
import 'settings_icon.dart';

class MessagePrimaryActions extends StatelessWidget {
  const MessagePrimaryActions({
    super.key,
    required this.allowQuote,
    required this.allowForward,
    required this.allowCopy,
    required this.allowStar,
    required this.starred,
    required this.onAction,
  });
  final bool allowQuote, allowForward, allowCopy, allowStar, starred;
  final ValueChanged<MessageAction> onAction;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    final actions = [
      (MessageAction.copy, '复制', allowCopy, CopyIcon(color: color)),
      (MessageAction.quote, '引用', allowQuote, QuoteIcon(color: color)),
      (
        MessageAction.star,
        starred ? '取消收藏' : '收藏',
        allowStar,
        SettingsIcon(
          type: starred ? SettingsIconType.starFilled : SettingsIconType.star,
          color: starred ? const Color(0xffe5ad24) : color,
        ),
      ),
      (
        MessageAction.forward,
        '转发',
        allowForward,
        AttachmentActionIcon(
          type: AttachmentActionIconType.forward,
          color: color,
        ),
      ),
    ].where((action) => action.$3).toList();
    if (actions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        spacing: 8,
        children: [
          for (final (action, label, _, icon) in actions)
            Expanded(
              child: Material(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).colorScheme.surfaceContainerHigh
                    : Colors.white,
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onAction(action),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox.square(
                          dimension: 24,
                          child: FittedBox(child: icon),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          style: TextStyle(fontSize: 13, color: color),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
