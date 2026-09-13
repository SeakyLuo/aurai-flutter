import 'package:flutter/material.dart';

class ToolExpandArrow extends StatelessWidget {
  const ToolExpandArrow({super.key, required this.expanded});
  final bool expanded;

  @override
  Widget build(BuildContext context) => AnimatedRotation(
    turns: expanded ? .25 : 0,
    duration: const Duration(milliseconds: 280),
    curve: Curves.easeInOutCubic,
    child: CustomPaint(
      size: const Size.square(18),
      painter: _ArrowPainter(Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    canvas.drawPath(
      Path()
        ..moveTo(9, 6)
        ..lineTo(15, 12)
        ..lineTo(9, 18),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.65
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) => oldDelegate.color != color;
}
