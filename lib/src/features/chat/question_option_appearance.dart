import 'package:flutter/material.dart';

/// Shared selection colors for question and vote options.
abstract final class QuestionOptionAppearance {
  static Color accent(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xffc4b5fd)
      : const Color(0xff7959df);

  static Color selectedBackground(BuildContext context) =>
      Theme.of(context).colorScheme.primary.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? .19 : .14,
      );

  static Color selectedBorder(BuildContext context) =>
      accent(context).withValues(alpha: .38);

  static Color selectedIndicator(BuildContext context) =>
      Theme.of(context).colorScheme.primary.withValues(alpha: .25);
}
