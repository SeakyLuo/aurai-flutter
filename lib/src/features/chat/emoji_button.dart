import 'package:flutter/material.dart';

import 'menu_press_highlight.dart';

/// Shared square surface for picker cells and message-menu reactions.
class EmojiButton extends StatelessWidget {
  const EmojiButton({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.selected = false,
    this.filled = false,
  });

  final Widget child;
  final VoidCallback onTap;
  final Future<void> Function()? onLongPress;
  final bool selected, filled;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1,
    child: MenuPressHighlight(
      onLongPressStart: onLongPress == null ? null : (_) => onLongPress!(),
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: selected || filled
            ? Theme.of(context).colorScheme.onSurface.withValues(alpha: .06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(child: child),
        ),
      ),
    ),
  );
}
