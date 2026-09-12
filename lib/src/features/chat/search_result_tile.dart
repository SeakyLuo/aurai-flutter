import 'package:flutter/material.dart';

import 'conversation.dart';
import 'conversation_icon.dart';
import 'glass_surface.dart';

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
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: GlassSurface(
          radius: 24,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colors.primary.withValues(alpha: .22),
                            colors.primary.withValues(alpha: .08),
                          ],
                        ),
                      ),
                      child: Center(
                        child: SizedBox.square(
                          dimension: 20,
                          child: ColorFiltered(
                            colorFilter: ColorFilter.mode(
                              dark
                                  ? const Color(0xffc4b5fd)
                                  : const Color(0xff7959df),
                              BlendMode.srcIn,
                            ),
                            child: const FittedBox(child: ConversationIcon()),
                          ),
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
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                              color: colors.onSurface,
                            ),
                          ),
                          if (conversation.isArchived)
                            Text(
                              '已归档',
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.onSurfaceVariant,
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
        ),
      ),
    );
  }
}
