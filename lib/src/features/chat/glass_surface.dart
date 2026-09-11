import 'dart:ui';

import 'package:flutter/material.dart';

class GlassSurface extends StatelessWidget {
  const GlassSurface({super.key, required this.child, this.radius = 32});
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(
          color: Color(0x10000000),
          blurRadius: 28,
          offset: Offset(0, 6),
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
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xfaffffff), Color(0xd9ffffff), Color(0xe8f6f8fb)],
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
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final Widget? iconWidget;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null,
    label: label,
    child: Tooltip(
      message: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: primary && onPressed != null
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xff3aa5ff), Color(0xff0875ee)],
                )
              : null,
          color: primary && onPressed == null ? const Color(0x0f171717) : null,
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: iconWidget != null
                ? Center(child: iconWidget)
                : Icon(
                    icon,
                    size: 25,
                    color: primary
                        ? (onPressed == null
                              ? const Color(0xffb0b4b9)
                              : Colors.white)
                        : const Color(0xff242424),
                  ),
          ),
        ),
      ),
    ),
  );
}
