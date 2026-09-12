import 'package:flutter/material.dart';

class TextSelectionIcon extends StatelessWidget {
  const TextSelectionIcon({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size.square(21),
    painter: _TextSelectionPainter(
      Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class _TextSelectionPainter extends CustomPainter {
  const _TextSelectionPainter(this.color);
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
        ..moveTo(6, 3.5)
        ..lineTo(3.5, 3.5)
        ..lineTo(3.5, 20.5)
        ..lineTo(6, 20.5)
        ..moveTo(18, 3.5)
        ..lineTo(20.5, 3.5)
        ..lineTo(20.5, 20.5)
        ..lineTo(18, 20.5)
        ..moveTo(8, 8)
        ..lineTo(16, 8)
        ..moveTo(8, 12)
        ..lineTo(16, 12)
        ..moveTo(8, 16)
        ..lineTo(13, 16),
      pen,
    );
  }

  @override
  bool shouldRepaint(_TextSelectionPainter oldDelegate) =>
      oldDelegate.color != color;
}
