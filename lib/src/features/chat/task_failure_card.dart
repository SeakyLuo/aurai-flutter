import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/glass_notice.dart';
import '../../app/ui_action.dart';

import '../../app/global_ui.dart';
import 'conversation_menu_icon.dart';
import 'glass_surface.dart';
import 'task_failure_icon.dart';
import 'task_playback_icon.dart';

class TaskFailureCard extends StatelessWidget {
  const TaskFailureCard({
    super.key,
    required this.onRetry,
    required this.error,
    this.actionLabel = '重试',
    this.paused,
    this.enabled = true,
  });
  final bool? paused;
  final bool enabled;
  final String error;
  final String actionLabel;
  final VoidCallback onRetry;

  Future<void> _copyError(BuildContext context) async {
    final copied = await runUiAction(
      context,
      () => Clipboard.setData(ClipboardData(text: error)),
    );
    if (copied && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showGlassSnackBar(const SnackBar(content: Text('已复制报错')));
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _copyError(context),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        decoration: BoxDecoration(
          color: paused != null
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : Theme.of(context).brightness == Brightness.dark
              ? const Color(0xff292529)
              : const Color(0xfffffcfd),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: paused != null
                ? Theme.of(context).colorScheme.outlineVariant
                : Theme.of(context).brightness == Brightness.dark
                ? const Color(0xff503940)
                : const Color(0xfffae9ee),
          ),
        ),
        child: Row(
          children: [
            const TaskFailureIcon(size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                error,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Transform.scale(
              scale: 0.85,
              alignment: Alignment.centerRight,
              transformHitTests: false,
              child: RoundAction(
                label: actionLabel,
                icon: Icons.refresh_rounded,
                iconWidget: paused == null
                    ? ConversationMenuIcon(
                        type: ConversationMenuIconType.retry,
                        color: enabled
                            ? GlobalUI.onPrimary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      )
                    : TaskPlaybackIcon(
                        paused: paused!,
                        color: enabled
                            ? GlobalUI.onPrimary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                primary: true,
                compact: true,
                inkResponse: false,
                onPressed: enabled ? onRetry : null,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
