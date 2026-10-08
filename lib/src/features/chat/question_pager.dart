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
      return Semantics(
        button: true,
        enabled: enabled,
        label: previous ? '上一题' : '下一题',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => onChanged(index + (previous ? -1 : 1)) : null,
          child: SizedBox.square(
            dimension: 24,
            child: RotatedBox(
              quarterTurns: previous ? 2 : 0,
              child: SettingsIcon(
                type: SettingsIconType.chevron,
                color: enabled
                    ? colors.onSurfaceVariant
                    : colors.onSurface.withValues(alpha: .25),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        arrow(true),
        const SizedBox(width: 2),
        Semantics(
          label: '第 ${index + 1} 题，共 $count 题',
          child: Text(
            '${index + 1}/$count',
            style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 2),
        arrow(false),
      ],
    );
  }
}
