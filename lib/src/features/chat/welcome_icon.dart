import 'package:flutter/material.dart';

enum WelcomeIconType { chat, network }

class WelcomeIcon extends StatelessWidget {
  const WelcomeIcon({super.key, required this.type});
  final WelcomeIconType type;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(type == WelcomeIconType.chat ? 28 : 24),
    painter: _WelcomePainter(
      type,
      Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class _WelcomePainter extends CustomPainter {
  const _WelcomePainter(this.type, this.color);
  final WelcomeIconType type;
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
    switch (type) {
      case WelcomeIconType.chat:
        canvas.drawPath(
          Path()
            ..moveTo(13, 3.5)
            ..lineTo(7, 3.5)
            ..quadraticBezierTo(3, 3.5, 3, 7.5)
            ..lineTo(3, 15)
            ..quadraticBezierTo(3, 18.5, 6.5, 18.5)
            ..lineTo(6.5, 21)
            ..lineTo(10.5, 18.5)
            ..lineTo(17, 18.5)
            ..quadraticBezierTo(21, 18.5, 21, 14.5)
            ..lineTo(21, 11)
            ..moveTo(7.5, 10)
            ..lineTo(12, 10)
            ..moveTo(7.5, 14)
            ..lineTo(15.5, 14)
            ..moveTo(18, 2)
            ..quadraticBezierTo(18, 6, 22, 6)
            ..quadraticBezierTo(18, 6, 18, 10)
            ..quadraticBezierTo(18, 6, 14, 6)
            ..quadraticBezierTo(18, 6, 18, 2),
          pen,
        );
      case WelcomeIconType.network:
        canvas.drawPath(
          Path()
            ..moveTo(3, 8)
            ..quadraticBezierTo(12, 1, 21, 8)
            ..moveTo(6, 11.5)
            ..quadraticBezierTo(12, 6.7, 18, 11.5)
            ..moveTo(9, 15)
            ..quadraticBezierTo(12, 12.5, 15, 15),
          pen,
        );
        canvas.drawCircle(const Offset(12, 18.5), .8, pen);
    }
  }

  @override
  bool shouldRepaint(_WelcomePainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}
