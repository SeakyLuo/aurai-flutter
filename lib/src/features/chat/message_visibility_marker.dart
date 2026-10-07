import 'package:flutter/material.dart';

import 'settings_icon.dart';

class MessageVisibilityMarker extends StatelessWidget {
  static const width = 24.0;
  const MessageVisibilityMarker({
    super.key,
    required this.isOwnMessage,
    required this.label,
    required this.onPressed,
    required this.child,
  });

  final bool isOwnMessage;
  final String label;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final marker = Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: SizedBox(
              width: width,
              height: 32,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox.square(
                  dimension: 16,
                  child: FittedBox(
                    child: SettingsIcon(
                      type: SettingsIconType.restrictedVisibility,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xffaaaaaa)
                          : const Color(0xff808080),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (isOwnMessage) marker,
        Flexible(child: child),
        if (!isOwnMessage) marker,
      ],
    );
  }
}
