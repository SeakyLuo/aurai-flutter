import 'package:flutter/material.dart';

class ConversationIcon extends StatelessWidget {
  const ConversationIcon({super.key, this.temporary = false, this.color});

  final bool temporary;
  final Color? color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size.square(22),
    painter: _ConversationPainter(
      color ?? Theme.of(context).colorScheme.onSurfaceVariant,
      temporary,
    ),
  );
}

class _ConversationPainter extends CustomPainter {
  const _ConversationPainter(this.color, this.temporary);
  final Color color;
  final bool temporary;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final outline = Path()
      ..moveTo(7, 20)
      ..lineTo(3.5, 21)
      ..lineTo(4.5, 17)
      ..cubicTo(2.8, 15, 2.4, 12, 3.5, 9)
      ..cubicTo(5, 4.5, 10, 2.5, 14.5, 3.7)
      ..cubicTo(19, 4.7, 22, 8.5, 21, 13)
      ..cubicTo(20, 18.8, 13, 22, 7, 20)
      ..close();
    if (temporary) {
      final metric = outline.computeMetrics().single;
      final step = metric.length / 8;
      for (var index = 0; index < 8; index++) {
        canvas.drawPath(
          metric.extractPath(index * step, (index + .6) * step),
          pen,
        );
      }
    } else {
      canvas.drawPath(outline, pen);
    }
  }

  @override
  bool shouldRepaint(_ConversationPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.temporary != temporary;
}
