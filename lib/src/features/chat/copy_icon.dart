import 'package:flutter/material.dart';

class CopyIcon extends StatelessWidget {
  const CopyIcon({super.key, this.copied = false, this.color});

  final bool copied;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 21,
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: CustomPaint(
        key: ValueKey(copied),
        size: const Size.square(21),
        painter: _CopyPainter(
          copied,
          color ?? Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}

class _CopyPainter extends CustomPainter {
  const _CopyPainter(this.copied, this.color);
  final Color color;

  final bool copied;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (copied) {
      canvas.drawPath(
        Path()
          ..moveTo(5, 12)
          ..lineTo(10, 17)
          ..lineTo(19, 7),
        pen,
      );
      return;
    }
    canvas.drawPath(
      Path()
        ..moveTo(6, 16)
        ..lineTo(5.5, 16)
        ..quadraticBezierTo(3, 16, 3, 13.5)
        ..lineTo(3, 5.5)
        ..quadraticBezierTo(3, 3, 5.5, 3)
        ..lineTo(13.5, 3)
        ..quadraticBezierTo(16, 3, 16, 5.5)
        ..lineTo(16, 6),
      pen,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(8, 8, 13, 13),
        const Radius.circular(2.5),
      ),
      pen,
    );
  }

  @override
  bool shouldRepaint(_CopyPainter oldDelegate) =>
      oldDelegate.copied != copied || oldDelegate.color != color;
}
