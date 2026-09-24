import 'package:flutter/material.dart';

class TaskPlaybackIcon extends StatelessWidget {
  const TaskPlaybackIcon({required this.paused, required this.color});
  final bool paused;
  final Color color;
  @override
  Widget build(BuildContext context) => paused
      ? Icon(Icons.play_arrow_rounded, color: color, size: 23)
      : CustomPaint(
          size: const Size.square(24),
          painter: _TaskPlaybackPainter(paused, color),
        );
}

class _TaskPlaybackPainter extends CustomPainter {
  const _TaskPlaybackPainter(this.paused, this.color);
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
  bool shouldRepaint(_TaskPlaybackPainter oldDelegate) =>
      oldDelegate.paused != paused || oldDelegate.color != color;
}
