import 'package:flutter/material.dart';

import 'question_option_appearance.dart';

String voteSelectionHint(int minimum, int maximum) => minimum == maximum
    ? '请选择 $minimum 项'
    : minimum == 1
    ? '最多选 $maximum 项'
    : '请选择 $minimum–$maximum 项';

class VoteSelectionHint extends StatelessWidget {
  const VoteSelectionHint({
    super.key,
    required this.minimum,
    required this.maximum,
    required this.selectedCount,
  });

  final int minimum, maximum, selectedCount;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 12,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Row(
      children: [
        Expanded(
          child: Text(voteSelectionHint(minimum, maximum), style: style),
        ),
        const SizedBox(width: 12),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: '已选 '),
              TextSpan(
                text: '$selectedCount',
                style: TextStyle(
                  color: QuestionOptionAppearance.accent(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(text: ' 项'),
            ],
          ),
          style: style,
        ),
      ],
    );
  }
}
