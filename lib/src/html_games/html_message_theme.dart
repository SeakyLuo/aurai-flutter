import '../app/global_ui.dart';
import 'package:flutter/material.dart';

/// HTML controls use the same semantic colors and typography as native controls.
String htmlMessageTheme(ThemeData theme) {
  final colors = theme.colorScheme;
  String css(Color color) =>
      '#${color.toARGB32().toRadixString(16).substring(2)}';
  return ':root{color-scheme:${theme.brightness == Brightness.dark ? 'dark' : 'light'};'
      '--aurai-message-background:${css(GlobalUI.messageBackground(theme))};'
      '--aurai-text:${css(colors.onSurface)};--aurai-muted:${css(colors.onSurfaceVariant)};'
      '--aurai-field:${css(GlobalUI.controlBackground(theme))};--aurai-border:${css(colors.outlineVariant)};'
      '--aurai-accent:${css(colors.primary)};--aurai-on-accent:${css(colors.onPrimary)};'
      '--aurai-font-size:${theme.textTheme.bodyMedium!.fontSize}px;'
      '--aurai-field-radius:${(theme.inputDecorationTheme.border as OutlineInputBorder).borderRadius.topLeft.x}px;--aurai-button-radius:24px;}';
}
