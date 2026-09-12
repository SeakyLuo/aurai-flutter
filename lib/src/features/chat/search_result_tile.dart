import 'package:flutter/material.dart';

import 'conversation.dart';
import 'conversation_icon.dart';

class SearchResultTile extends StatelessWidget {
  const SearchResultTile({
    super.key,
    required this.conversation,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final Conversation conversation;
  final InlineSpan title;
  final InlineSpan? subtitle;
  final VoidCallback onTap;

  String get _time {
    final now = DateTime.now();
    final date = conversation.updatedAt;
    final days = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(date.year, date.month, date.day)).inDays;
    if (now.difference(date).inMinutes < 1) return '刚刚';
    if (days == 0) return '今天';
    if (days == 1) return '昨天';
    return date.year == now.year
        ? '${date.month}月${date.day}日'
        : '${date.year}年${date.month}月${date.day}日';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: dark ? const Color(0x882d293b) : const Color(0xbfffffff),
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.primary.withValues(alpha: .12),
                  ),
                  child: const Center(
                    child: SizedBox.square(
                      dimension: 20,
                      child: FittedBox(child: ConversationIcon()),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text.rich(
                        subtitle ?? TextSpan(text: _time),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
