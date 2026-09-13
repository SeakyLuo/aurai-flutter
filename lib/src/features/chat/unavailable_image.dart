import 'package:flutter/material.dart';
import 'attachment_action_icon.dart';
import 'settings_appearance.dart';

class UnavailableImage extends StatelessWidget {
  const UnavailableImage({super.key, this.dark = false});
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final color = dark
        ? Colors.white60
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Semantics(
      label: '图片不可用',
      child: ColoredBox(
        color: dark ? Colors.black : settingsFieldColor(context),
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AttachmentActionIcon(
                  type: AttachmentActionIconType.gallery,
                  color: color,
                ),
                if (constraints.maxWidth >= 96 &&
                    constraints.maxHeight >= 72) ...[
                  const SizedBox(height: 8),
                  Text(
                    '图片不可用',
                    style: TextStyle(color: color, fontSize: 12, height: 1.3),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
