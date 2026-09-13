import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'thinking_indicator.dart';

class ReconnectIndicator extends StatelessWidget {
  const ReconnectIndicator({super.key, required this.attempt});
  final int attempt;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
    child: Row(
      children: [
        CustomPaint(
          size: Size.square(MediaQuery.textScalerOf(context).scale(18)),
          painter: _ConnectionIcon(
            Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ThinkingIndicator(
            label: '正在重新连接 $attempt/5',
            singleLine: true,
          ),
        ),
      ],
    ),
  );
}

class _ConnectionIcon extends CustomPainter {
  const _ConnectionIcon(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round;
    for (final radius in [13.0, 9.0, 5.0]) {
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(12, 20), radius: radius),
        math.pi * 1.25,
        math.pi * .5,
        false,
        pen,
      );
    }
    canvas.drawCircle(const Offset(12, 20), 1, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ConnectionIcon oldDelegate) => oldDelegate.color != color;
}
