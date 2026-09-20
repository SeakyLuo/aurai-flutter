import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../../app/global_ui.dart';

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 32,
    this.borderRadius,
    this.dark = false,
    this.regular = false,
    this.tintOpacity = 1,
    this.shadowOpacity = 1,
    this.gradientColors,
  });
  final Widget child;
  final double radius;
  final BorderRadius? borderRadius;
  final bool dark;
  final bool regular;
  final double tintOpacity;
  final double shadowOpacity;
  final List<Color>? gradientColors;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: borderRadius ?? BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: const Color(
            0x10000000,
          ).withValues(alpha: 16 / 255 * shadowOpacity),
          blurRadius: 6,
          offset: const Offset(0, 1),
        ),
        BoxShadow(
          color: const Color(
            0x04000000,
          ).withValues(alpha: 4 / 255 * shadowOpacity),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(radius),
      child: BackdropFilter.grouped(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius ?? BorderRadius.circular(radius),
            border: Border.all(
              color: (dark || Theme.of(context).brightness == Brightness.dark)
                  ? const Color(0x38ffffff)
                  : const Color(0xcfffffff),
              width: 1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors:
                  (gradientColors ??
                          (regular
                              ? (dark ||
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                    ? const [
                                        Color(0xf238383a),
                                        Color(0xeb303032),
                                        Color(0xf2333335),
                                      ]
                                    : const [
                                        Color(0xfaffffff),
                                        Color(0xf2ffffff),
                                        Color(0xf7f8f8fa),
                                      ])
                              : (dark ||
                                    Theme.of(context).brightness ==
                                        Brightness.dark)
                              ? const [
                                  Color(0xb348484b),
                                  Color(0x99202023),
                                  Color(0xc22b2b2e),
                                ]
                              : const [
                                  Color(0xe0ffffff),
                                  Color(0xb8ffffff),
                                  Color(0xccf2effa),
                                ]))
                      .map(
                        (color) =>
                            color.withValues(alpha: color.a * tintOpacity),
                      )
                      .toList(),
            ),
          ),
          child: RepaintBoundary(child: child),
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
    this.inkResponse = true,
    this.insetResponse = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final Widget? iconWidget;
  final bool compact;
  final bool inkResponse;
  final bool insetResponse;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null,
    label: label,
    child: Tooltip(
      message: label,
      child: SizedBox.square(
        dimension: compact ? 48 : 40,
        child: Padding(
          padding: EdgeInsets.all(insetResponse ? 6 : 0),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: _RoundActionTap(
              inkResponse: inkResponse,
              onPressed: onPressed,
              child: Padding(
                padding: EdgeInsets.all(compact && !insetResponse ? 6 : 0),
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
                    child: iconWidget != null
                        ? (compact
                              ? iconWidget
                              : SizedBox.square(
                                  dimension: 20,
                                  child: FittedBox(child: iconWidget),
                                ))
                        : Icon(
                            icon,
                            size: compact ? 23 : 20,
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
    ),
  );
}

class _RoundActionTap extends StatelessWidget {
  const _RoundActionTap({
    required this.inkResponse,
    required this.onPressed,
    required this.child,
  });
  final bool inkResponse;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) => inkResponse
      ? InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: child,
        )
      : CupertinoButton(
          padding: EdgeInsets.zero,
          pressedOpacity: 0.6,
          onPressed: onPressed,
          child: child,
        );
}
