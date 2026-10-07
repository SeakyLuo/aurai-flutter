import 'package:flutter/material.dart';

import 'settings_icon.dart';

/// Navigation for a question batch; the counter describes position, not answers.
class QuestionPager extends StatelessWidget {
  const QuestionPager({
    super.key,
    required this.index,
    required this.count,
    required this.onChanged,
  });

  final int index, count;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    if (count == 1) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    Widget arrow(bool previous) {
      final enabled = previous ? index > 0 : index < count - 1;
      return IconButton(
        constraints: const BoxConstraints.tightFor(width: 32, height: 40),
        padding: const EdgeInsets.all(4),
        visualDensity: VisualDensity.compact,
        tooltip: previous ? '上一题' : '下一题',
        onPressed: enabled
            ? () => onChanged(index + (previous ? -1 : 1))
            : null,
        icon: RotatedBox(
          quarterTurns: previous ? 2 : 0,
          child: SettingsIcon(
            type: SettingsIconType.chevron,
            color: enabled
                ? colors.onSurfaceVariant
                : colors.onSurface.withValues(alpha: .25),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        arrow(true),
        Semantics(
          label: '第 ${index + 1} 题，共 $count 题',
          child: Text(
            '${index + 1}/$count',
            style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
          ),
        ),
        arrow(false),
      ],
    );
  }
}
