import 'package:flutter/material.dart';

import '../../utils/widget_utils.dart';
import 'settings_icon.dart';

class QuestionNavigation extends StatelessWidget {
  const QuestionNavigation({
    super.key,
    required this.index,
    required this.count,
    required this.busy,
    required this.onPrevious,
    required this.onNext,
    this.submitLabel = '提交回答',
  });

  final int index, count;
  final bool busy;
  final VoidCallback onPrevious, onNext;
  final String submitLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (count > 1) ...[
          Semantics(
            label: '上一题，当前第 ${index + 1} 题，共 $count 题',
            child: SizedBox.square(
              dimension: 48,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  OutlinedButton(
                    onPressed: index == 0 || busy ? null : onPrevious,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: const CircleBorder(),
                      side: BorderSide(color: colors.outlineVariant),
                      foregroundColor: colors.onSurfaceVariant,
                      disabledForegroundColor: colors.onSurfaceVariant,
                    ),
                    child: RotatedBox(
                      quarterTurns: 2,
                      child: SettingsIcon(
                        type: SettingsIconType.chevron,
                        color: index == 0 || busy
                            ? colors.onSurface.withValues(alpha: .25)
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: (index + 1) / count),
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      builder: (context, value, _) => CircularProgressIndicator(
                        value: value,
                        strokeWidth: 2,
                        strokeCap: StrokeCap.round,
                        color: colors.primary,
                        backgroundColor: Colors.transparent,
                        trackGap: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: WidgetUtils.primaryButton(
            text: index < count - 1 ? '下一题' : submitLabel,
            loading: busy,
            onPressed: busy ? null : onNext,
          ),
        ),
      ],
    );
  }
}
