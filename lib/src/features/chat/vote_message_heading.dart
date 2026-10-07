import 'package:flutter/material.dart';

import 'question_icon.dart';
import 'interactive_status_tag.dart';

class VoteMessageHeading extends StatelessWidget {
  const VoteMessageHeading({
    super.key,
    required this.title,
    required this.multiple,
    required this.ongoing,
    required this.anonymous,
    this.status,
    this.trailing,
  });

  final String title;
  final bool multiple;
  final bool ongoing;
  final bool anonymous;
  final String? status;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Selection limits describe multiple choice; omit the redundant title suffix.
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
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              anonymous ? '匿名投票' : '投票',
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
            const Spacer(),
            if (status != null)
              InteractiveStatusTag(label: status!, highlighted: ongoing),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
        const SizedBox(height: 8),
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
