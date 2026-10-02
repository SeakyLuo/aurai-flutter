import 'package:flutter/material.dart';

import '../features/chat/attachment_action_icon.dart';
import '../features/chat/settings_icon.dart';

/// Shared symbol for miniapp entry points, tools and default application icons.
class MiniappSymbol extends StatelessWidget {
  const MiniappSymbol({super.key, this.color, this.size = 24});
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: FittedBox(
      child: AttachmentActionIcon(
        type: AttachmentActionIconType.html,
        color: color ?? settingsIconColor(context),
      ),
    ),
  );
}
