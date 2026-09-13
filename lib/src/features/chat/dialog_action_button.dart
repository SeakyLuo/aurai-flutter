import 'package:flutter/material.dart';

import '../../utils/widget_utils.dart';
import 'settings_appearance.dart';

enum DialogActionRole { primary, secondary, destructive, reject }

/// Dialog actions share sizing, shape and colors; callers supply behavior only.
class DialogActionButton extends StatelessWidget {
  const DialogActionButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.role = DialogActionRole.primary,
    this.detail,
    this.loading = false,
  });

  final String text;
  final VoidCallback? onPressed;
  final DialogActionRole role;
  final String? detail;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final label = detail == null ? text : '$text · $detail';
    if (role == DialogActionRole.primary) {
      return WidgetUtils.primaryButton(
        text: label,
        onPressed: onPressed,
        height: 46,
        loading: loading,
      );
    }
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final destructive = role == DialogActionRole.destructive;
    return TextButton(
      onPressed: loading ? null : onPressed,
      style: TextButton.styleFrom(
        foregroundColor: destructive || role == DialogActionRole.reject
            ? (dark ? const Color(0xffff8a80) : const Color(0xffd93025))
            : colors.onSurface,
        backgroundColor: destructive
            ? (dark ? const Color(0xff492b2b) : const Color(0xffffe9e7))
            : dialogControlColor(context),
        minimumSize: const Size(0, 46),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      child: loading
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label, textAlign: TextAlign.center),
    );
  }
}
