import 'package:flutter/material.dart';

class MessageJumpArrow extends StatelessWidget {
  const MessageJumpArrow({super.key, required this.color, this.upward = false});
  final Color color;
  final bool upward;

  @override
  Widget build(BuildContext context) => RotatedBox(
    quarterTurns: upward ? 0 : 2,
    child: CustomPaint(
      size: const Size(18, 18),
      painter: _JumpArrowPainter(color),
    ),
  );
}

class _JumpArrowPainter extends CustomPainter {
  const _JumpArrowPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(6, 12)
        ..lineTo(12, 6)
        ..lineTo(18, 12)
        ..moveTo(6, 18)
        ..lineTo(12, 12)
        ..lineTo(18, 18),
      paint,
    );
  }

  @override
  bool shouldRepaint(_JumpArrowPainter oldDelegate) =>
      oldDelegate.color != color;
}
