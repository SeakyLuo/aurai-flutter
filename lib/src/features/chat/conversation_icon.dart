import 'package:flutter/material.dart';

class ConversationIcon extends StatelessWidget {
  const ConversationIcon({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size.square(22),
    painter: _ConversationPainter(
      Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class _ConversationPainter extends CustomPainter {
  const _ConversationPainter(this.color);
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
    canvas.drawPath(
      Path()
        ..moveTo(7, 3.5)
        ..lineTo(17, 3.5)
        ..quadraticBezierTo(21, 3.5, 21, 7.5)
        ..lineTo(21, 14)
        ..quadraticBezierTo(21, 18, 17, 18)
        ..lineTo(10, 18)
        ..lineTo(6, 21)
        ..lineTo(6, 17.9)
        ..quadraticBezierTo(3, 17.5, 3, 14)
        ..lineTo(3, 7.5)
        ..quadraticBezierTo(3, 3.5, 7, 3.5)
        ..close()
        ..moveTo(7.5, 8.5)
        ..lineTo(16.5, 8.5)
        ..moveTo(7.5, 12.5)
        ..lineTo(13.5, 12.5),
      pen,
    );
  }

  @override
  bool shouldRepaint(_ConversationPainter oldDelegate) =>
      oldDelegate.color != color;
}
