import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../../app/global_ui.dart';

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 32,
    this.dark = false,
    this.regular = false,
  });
  final Widget child;
  final double radius;
  final bool dark;
  final bool regular;

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
              colors: regular
                  ? (dark || Theme.of(context).brightness == Brightness.dark
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
                  : (dark || Theme.of(context).brightness == Brightness.dark)
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
