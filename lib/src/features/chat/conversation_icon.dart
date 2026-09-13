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
        ..moveTo(7, 20)
        ..lineTo(3.5, 21)
        ..lineTo(4.5, 17)
        ..cubicTo(2.8, 15, 2.4, 12, 3.5, 9)
        ..cubicTo(5, 4.5, 10, 2.5, 14.5, 3.7)
        ..cubicTo(19, 4.7, 22, 8.5, 21, 13)
        ..cubicTo(20, 18.8, 13, 22, 7, 20)
        ..close(),
      pen,
    );
  }

  @override
  bool shouldRepaint(_ConversationPainter oldDelegate) =>
      oldDelegate.color != color;
}
