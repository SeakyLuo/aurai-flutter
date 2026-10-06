import 'package:flutter/material.dart';

import 'vote_appearance.dart';
import 'question_icon.dart';

class VoteMessageHeading extends StatelessWidget {
  const VoteMessageHeading({
    super.key,
    required this.title,
    required this.multiple,
    required this.ongoing,
    this.trailing,
  });

  final String title;
  final bool multiple;
  final bool ongoing;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Selection mode already has its own label; omit the duplicate title suffix.
    final displayTitle = multiple
        ? title.replaceFirst(RegExp(r'\s*[（(]可多选[）)]\s*$'), '')
        : title;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            QuestionIcon(
              type: QuestionIconType.vote,
              color: ongoing ? colors.primary : colors.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              '投票',
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
            const Spacer(),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: .2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                child: Text(
                  multiple ? '多选' : '单选',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: VoteAppearance.accent(context),
                  ),
                ),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
        const SizedBox(height: 14),
        Text(
          displayTitle,
          style: TextStyle(
            fontSize: 17,
            height: 1.4,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
      ],
    );
  }
}
