import 'package:flutter/material.dart';

import 'dialog_action_button.dart';
import 'glass_surface.dart';

class ArchiveConfirmationDialog extends StatelessWidget {
  const ArchiveConfirmationDialog({super.key, required this.isCurrent});
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: GlassSurface(
          radius: 28,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '归档会话？',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${isCurrent ? '归档后将退出当前会话。' : ''}消息和草稿会保留，可在设置的“已归档会话”中查看或取消归档。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: DialogActionButton(
                        text: '取消',
                        onPressed: () => Navigator.pop(context, false),
                        role: DialogActionRole.secondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DialogActionButton(
                        text: '归档',
                        onPressed: () => Navigator.pop(context, true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
