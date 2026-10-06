import 'package:flutter/material.dart';

import 'interactive_message_button.dart';

abstract final class VoteAppearance {
  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xffa88af4), Color(0xff845de0)],
  );

  static Color accent(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xffc4b5fd)
      : const Color(0xff7959df);

  static Color selectedBackground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Theme.of(context).colorScheme.primary.withValues(alpha: .19)
      : const Color(0xfff1ecff);

  static Color selectedBorder(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? accent(context).withValues(alpha: .5)
      : const Color(0xffcdbbff);
}

class VoteSubmitButton extends StatelessWidget {
  const VoteSubmitButton({
    super.key,
    required this.locked,
    required this.onPressed,
    this.busy = false,
  });

  final bool locked, busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => InteractiveMessageButton(
    button: {'label': '提交投票', 'style': 'primary', 'disabled': locked},
    busy: busy,
    locked: locked,
    onPressed: onPressed,
    primaryGradient: VoteAppearance.gradient,
    radius: 14,
    minimumHeight: 48,
    fontSize: 15,
  );
}
