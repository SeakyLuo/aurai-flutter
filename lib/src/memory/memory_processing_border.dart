import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Paints progress without changing the composer's size or rebuilding its input.
class MemoryProcessingBorder extends StatefulWidget {
  const MemoryProcessingBorder({
    super.key,
    required this.active,
    required this.child,
  });

  final bool active;
  final Widget child;

  @override
  State<MemoryProcessingBorder> createState() => _MemoryProcessingBorderState();
}

class _MemoryProcessingBorderState extends State<MemoryProcessingBorder>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  void _syncAnimation() {
    if (widget.active && !MediaQuery.disableAnimationsOf(context)) {
      _animation.repeat();
    } else {
      _animation.stop();
      _animation.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(MemoryProcessingBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _syncAnimation();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: widget.active
        ? _ProcessingBorderPainter(
            animation: _animation,
            color: Theme.of(context).colorScheme.primary,
          )
        : null,
    child: widget.child,
  );
}

class _ProcessingBorderPainter extends CustomPainter {
  _ProcessingBorderPainter({required this.animation, required this.color})
    : super(repaint: animation);

  final Animation<double> animation;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(1);
    final border = RRect.fromRectAndRadius(rect, const Radius.circular(27));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = SweepGradient(
        colors: [
          color.withValues(alpha: .08),
          color.withValues(alpha: .08),
          color.withValues(alpha: .65),
          color.withValues(alpha: .08),
        ],
        stops: const [0, .55, .82, 1],
        transform: GradientRotation(animation.value * math.pi * 2),
      ).createShader(rect);
    canvas.drawRRect(border, paint);
  }

  @override
  bool shouldRepaint(_ProcessingBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.animation != animation;
}
