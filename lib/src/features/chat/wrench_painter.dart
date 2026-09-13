import 'package:flutter/material.dart';

class WrenchPainter extends CustomPainter {
  const WrenchPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(14, 3.2)
        ..cubicTo(10.4, 3, 8.1, 6.4, 9.3, 9.6)
        ..lineTo(3.8, 15.1)
        ..cubicTo(.6, 18.3, 5.7, 23.4, 8.9, 20.2)
        ..lineTo(14.4, 14.7)
        ..cubicTo(17.6, 15.9, 21, 13.6, 20.8, 10)
        ..lineTo(17.7, 12)
        ..lineTo(14, 8.3)
        ..lineTo(14, 3.2)
        ..close(),
      pen,
    );
    canvas.drawCircle(const Offset(6, 18), .8, Paint()..color = color);
  }

  @override
  bool shouldRepaint(WrenchPainter oldDelegate) => oldDelegate.color != color;
}
