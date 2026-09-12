import 'package:flutter/material.dart';

class ComposeIcon extends StatelessWidget {
  const ComposeIcon({super.key, this.color});
  final Color? color;
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size.square(24),
    painter: _ComposePainter(color ?? Theme.of(context).colorScheme.onSurface),
  );
}

class _ComposePainter extends CustomPainter {
  const _ComposePainter(this.color);
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
        ..moveTo(12, 4)
        ..lineTo(6, 4)
        ..quadraticBezierTo(3.5, 4, 3.5, 6.5)
        ..lineTo(3.5, 18)
        ..quadraticBezierTo(3.5, 20.5, 6, 20.5)
        ..lineTo(17.5, 20.5)
        ..quadraticBezierTo(20, 20.5, 20, 18)
        ..lineTo(20, 12),
      pen,
    );
    canvas.drawPath(
      Path()
        ..moveTo(10, 10.5)
        ..lineTo(17.5, 3)
        ..quadraticBezierTo(18.5, 2, 19.5, 3)
        ..lineTo(21, 4.5)
        ..quadraticBezierTo(22, 5.5, 21, 6.5)
        ..lineTo(13.5, 14)
        ..lineTo(9, 15)
        ..close()
        ..moveTo(16.5, 4)
        ..lineTo(20, 7.5),
      pen,
    );
  }

  @override
  bool shouldRepaint(_ComposePainter oldDelegate) => oldDelegate.color != color;
}
