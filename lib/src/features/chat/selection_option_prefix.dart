import 'package:flutter/material.dart';

import 'question_option_appearance.dart';

/// Presentation only; option identities and submitted values never use labels.
class SelectionOptionPrefix extends StatelessWidget {
  const SelectionOptionPrefix({
    super.key,
    required this.number,
    required this.style,
    required this.selected,
  });

  final int number;
  final String style;
  final bool selected;

  static String letters(int number) {
    var label = '';
    while (number > 0) {
      number--;
      label = String.fromCharCode(65 + number % 26) + label;
      number ~/= 26;
    }
    return label;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = selected
        ? QuestionOptionAppearance.accent(context)
        : colors.onSurfaceVariant;
    if (style == 'dot') {
      return SizedBox(
        width: 12,
        child: Center(
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      );
    }
    final size = MediaQuery.textScalerOf(context).scale(22);
    return Container(
      constraints: BoxConstraints(minWidth: size),
      height: size,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size / 2),
        color: selected
            ? QuestionOptionAppearance.selectedIndicator(context)
            : colors.onSurface.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? .12
                    : .08,
              ),
      ),
      child: Text(
        style == 'letter' ? letters(number) : '$number',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
