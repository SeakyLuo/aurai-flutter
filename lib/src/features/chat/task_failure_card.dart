import 'package:flutter/material.dart';

import 'glass_surface.dart';
import 'task_failure_icon.dart';

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
          if (paused == null)
            const TaskFailureIcon(size: 22)
          else
            _PlaybackIcon(paused: paused!),
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
              icon: Icons.refresh_rounded,
              iconWidget: paused == null
                  ? null
                  : _PlaybackIcon(paused: paused!),
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

class _PlaybackIcon extends StatelessWidget {
  const _PlaybackIcon({required this.paused});
  final bool paused;
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size.square(24),
    painter: _PlaybackPainter(
      paused,
      IconTheme.of(context).color ??
          Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class _PlaybackPainter extends CustomPainter {
  const _PlaybackPainter(this.paused, this.color);
  final bool paused;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (paused) {
      canvas.drawPath(
        Path()
          ..moveTo(8, 5)
          ..lineTo(19, 12)
          ..lineTo(8, 19)
          ..close(),
        pen,
      );
    } else {
      canvas.drawLine(const Offset(8, 6), const Offset(8, 18), pen);
      canvas.drawLine(const Offset(16, 6), const Offset(16, 18), pen);
    }
  }

  @override
  bool shouldRepaint(_PlaybackPainter oldDelegate) =>
      oldDelegate.paused != paused || oldDelegate.color != color;
}
