import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/global_ui.dart';

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 32,
    this.dark = false,
  });
  final Widget child;
  final double radius;
  final bool dark;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(
          color: Color(0x10000000),
          blurRadius: 6,
          offset: Offset(0, 1),
        ),
        BoxShadow(
          color: Color(0x04000000),
          blurRadius: 3,
          offset: Offset(0, 1),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter.grouped(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: (dark || Theme.of(context).brightness == Brightness.dark)
                  ? const Color(0x38ffffff)
                  : const Color(0xcfffffff),
              width: 1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: (dark || Theme.of(context).brightness == Brightness.dark)
                  ? const [
                      Color(0xb348484b),
                      Color(0x99202023),
                      Color(0xc22b2b2e),
                    ]
                  : const [
                      Color(0xe0ffffff),
                      Color(0xb8ffffff),
                      Color(0xccf2effa),
                    ],
            ),
          ),
          child: child,
        ),
      ),
    ),
  );
}

class RoundAction extends StatelessWidget {
  const RoundAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.iconWidget,
    this.compact = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final Widget? iconWidget;
  final bool compact;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null,
    label: label,
    child: Tooltip(
      message: label,
      child: SizedBox.square(
        dimension: 48,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Padding(
              padding: EdgeInsets.all(compact ? 6 : 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: primary && onPressed != null
                      ? GlobalUI.primaryGradient
                      : null,
                  color: primary && onPressed == null
                      ? Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.06)
                      : null,
                ),
                child: Center(
                  child:
                      iconWidget ??
                      Icon(
                        icon,
                        size: compact ? 23 : 25,
                        color: primary
                            ? (onPressed == null
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant
                                  : GlobalUI.onPrimary)
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
