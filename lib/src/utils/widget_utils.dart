import 'dart:ui';

import 'package:flutter/material.dart';

import '../app/global_ui.dart';

abstract final class WidgetUtils {
  static Widget primaryButton({
    required String text,
    required VoidCallback? onPressed,
    Widget? icon,
    bool loading = false,
    bool frosted = false,
    bool liquidGlass = false,
    Color textColor = GlobalUI.onPrimary,
    double? width,
    double height = 48,
    double fontSize = 15,
  }) {
    final shape = StadiumBorder();
    final button = SizedBox(
      width: width,
      height: height,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        clipBehavior: Clip.antiAlias,
        style: FilledButton.styleFrom(
          foregroundColor: textColor,
          backgroundColor: liquidGlass ? Colors.transparent : null,
          elevation: frosted && !liquidGlass ? 2 : 0,
          shadowColor: GlobalUI.buttonShadow,
          surfaceTintColor: Colors.transparent,
          side: frosted && onPressed != null
              ? const BorderSide(color: GlobalUI.frostedBorder)
              : BorderSide.none,
          minimumSize: Size(48, height),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: shape,
          textStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
          backgroundBuilder: (context, states, child) => DecoratedBox(
            decoration: ShapeDecoration(
              shape: shape,
              gradient: states.contains(WidgetState.disabled)
                  ? null
                  : liquidGlass
                  ? (Theme.of(context).brightness == Brightness.dark
                        ? GlobalUI.darkLiquidGlassGradient
                        : GlobalUI.liquidGlassGradient)
                  : GlobalUI.primaryGradient,
            ),
            child: frosted && !states.contains(WidgetState.disabled)
                ? DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: shape,
                      gradient: GlobalUI.frostedHighlight,
                    ),
                    child: child,
                  )
                : child,
          ),
        ),
        child: loading
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[icon, const SizedBox(width: 8)],
                  Flexible(child: Text(text, textAlign: TextAlign.center)),
                ],
              ),
      ),
    );
    if (!liquidGlass) return button;
    return DecoratedBox(
      decoration: const ShapeDecoration(
        shape: StadiumBorder(),
        shadows: [
          BoxShadow(
            color: GlobalUI.buttonShadow,
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: GlobalUI.liquidGlassBlur,
            sigmaY: GlobalUI.liquidGlassBlur,
          ),
          child: button,
        ),
      ),
    );
  }
}
