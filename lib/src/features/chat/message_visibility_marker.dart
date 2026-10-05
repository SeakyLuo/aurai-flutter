import 'package:flutter/material.dart';

import 'settings_icon.dart';

class MessageVisibilityMarker extends StatelessWidget {
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
    final marker = Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Tooltip(
        message: label,
        child: Semantics(
          button: true,
          label: label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onPressed,
              child: const SizedBox(
                width: 32,
                height: 32,
                child: Center(
                  child: SizedBox.square(
                    dimension: 18,
                    child: FittedBox(
                      child: SettingsIcon(type: SettingsIconType.eye),
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
