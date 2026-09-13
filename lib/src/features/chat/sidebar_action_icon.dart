import 'dart:math' as math;

import 'package:flutter/material.dart';

enum SidebarActionIconType { search, settings, group, add }

class SidebarActionIcon extends StatelessWidget {
  const SidebarActionIcon({super.key, required this.type, this.color});

  final SidebarActionIconType type;
  final Color? color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size.square(24),
    painter: _SidebarActionPainter(
      type,
      color ??
          (Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : const Color(0xff222222)),
    ),
  );
}

class _SidebarActionPainter extends CustomPainter {
  const _SidebarActionPainter(this.type, this.color);
  final Color color;

  final SidebarActionIconType type;

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
      case SidebarActionIconType.add:
        canvas.drawLine(const Offset(5, 12), const Offset(19, 12), pen);
        canvas.drawLine(const Offset(12, 5), const Offset(12, 19), pen);
      case SidebarActionIconType.group:
        canvas.drawCircle(const Offset(9, 7.5), 3, pen);
        canvas.drawPath(
          Path()
            ..moveTo(3, 20)
            ..lineTo(3, 18)
            ..cubicTo(3, 11.5, 15, 11.5, 15, 18)
            ..lineTo(15, 20),
          pen,
        );
        canvas.drawPath(
          Path()
            ..moveTo(16, 4.8)
            ..cubicTo(20.8, 4.6, 21.2, 10, 17, 10.5),
          pen,
        );
        canvas.drawPath(
          Path()
            ..moveTo(18, 14)
            ..cubicTo(20.4, 14.6, 21, 16.3, 21, 18.5)
            ..lineTo(21, 20),
          pen,
        );
      case SidebarActionIconType.search:
        canvas.drawCircle(const Offset(10.5, 10.5), 6.75, pen);
        canvas.drawLine(
          const Offset(15.4, 15.4),
          const Offset(20.5, 20.5),
          pen,
        );
      case SidebarActionIconType.settings:
        final points = <Offset>[];
        for (var tooth = 0; tooth < 8; tooth++) {
          final angle = tooth * math.pi / 4;
          for (final corner in const [
            (-0.38, 7.25),
            (-0.22, 9.5),
            (0.22, 9.5),
            (0.38, 7.25),
          ]) {
            final theta = angle + corner.$1 * math.pi / 4;
            points.add(
              Offset(
                12 + math.cos(theta) * corner.$2,
                12 + math.sin(theta) * corner.$2,
              ),
            );
          }
        }
        final start = Offset.lerp(points.last, points.first, 0.5)!;
        final outline = Path()..moveTo(start.dx, start.dy);
        for (var i = 0; i < points.length; i++) {
          final corner = points[i];
          final next = points[(i + 1) % points.length];
          final midpoint = Offset.lerp(corner, next, 0.5)!;
          outline.quadraticBezierTo(
            corner.dx,
            corner.dy,
            midpoint.dx,
            midpoint.dy,
          );
        }
        canvas.drawPath(outline..close(), pen);
        canvas.drawCircle(const Offset(12, 12), 3.1, pen);
    }
  }

  @override
  bool shouldRepaint(_SidebarActionPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}
