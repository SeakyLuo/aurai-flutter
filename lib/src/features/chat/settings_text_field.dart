import 'package:flutter/material.dart';
import 'settings_appearance.dart';

InputDecoration settingsTextFieldDecoration(
  BuildContext context, {
  required String hint,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(26),
    borderSide: BorderSide.none,
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      fontSize: 15,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
    filled: true,
    fillColor: settingsFieldColor(context),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
    prefixIcon: prefixIcon,
    prefixIconConstraints: prefixIcon == null
        ? null
        : const BoxConstraints(minWidth: 60, minHeight: 48),
    border: border,
    enabledBorder: border,
    focusedBorder: border,
    disabledBorder: border,
    suffixIcon: suffixIcon,
  );
}

class SettingsFieldLabel extends StatelessWidget {
  const SettingsFieldLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 15,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
