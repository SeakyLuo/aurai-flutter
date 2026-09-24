import 'package:flutter/material.dart';

import '../../app/global_ui.dart';
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

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
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
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
            ),
          ),
          const SizedBox(width: 12),
          Transform.scale(
            scale: 0.85,
            alignment: Alignment.centerRight,
            transformHitTests: false,
            child: RoundAction(
              label: actionLabel,
              icon: paused == true
                  ? Icons.play_arrow_rounded
                  : Icons.refresh_rounded,
              iconWidget: paused != false
                  ? null
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
  );
}
