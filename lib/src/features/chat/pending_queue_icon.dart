import 'package:flutter/material.dart';

class PendingQueueIcon extends StatelessWidget {
  const PendingQueueIcon({super.key, required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size.square(18), painter: _QueuePainter(color));
}

class _QueuePainter extends CustomPainter {
  const _QueuePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final pen = Paint()
      ..color = color
      ..strokeWidth = 1.65
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(5, 4)
        ..lineTo(5, 16)
        ..quadraticBezierTo(5, 19, 8, 19)
        ..lineTo(20, 19)
        ..moveTo(17, 16)
        ..lineTo(20, 19)
        ..lineTo(17, 22)
        ..moveTo(10, 6)
        ..lineTo(19, 6)
        ..moveTo(10, 11)
        ..lineTo(16, 11),
      pen,
    );
  }

  @override
  bool shouldRepaint(_QueuePainter oldDelegate) => color != oldDelegate.color;
}
