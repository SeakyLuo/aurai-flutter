import 'package:flutter/material.dart';

import 'question_option_appearance.dart';

class InteractiveStatusTag extends StatelessWidget {
  const InteractiveStatusTag({
    super.key,
    required this.label,
    required this.highlighted,
  });

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: highlighted
            ? colors.primary.withValues(alpha: .22)
            : colors.onSurface.withValues(alpha: .045),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            height: 1.3,
            fontWeight: highlighted ? FontWeight.w500 : FontWeight.w400,
            color: highlighted
                ? QuestionOptionAppearance.accent(context)
                : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
