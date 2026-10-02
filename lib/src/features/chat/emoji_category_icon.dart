import 'package:flutter/material.dart';
import 'settings_icon.dart';

/// Matches the shared 24px, rounded 1.65px outline icon style.
class EmojiCategoryIcon extends StatelessWidget {
  const EmojiCategoryIcon({
    super.key,
    required this.category,
    required this.color,
  });
  final int category;
  final Color color;

  @override
  Widget build(BuildContext context) => switch (category) {
    -1 => SettingsIcon(type: SettingsIconType.grid, color: color),
    1 => SettingsIcon(type: SettingsIconType.personalInfo, color: color),
    _ => CustomPaint(
      size: const Size.square(24),
      painter: _CategoryPainter(category, color),
    ),
  };
}

class _CategoryPainter extends CustomPainter {
  const _CategoryPainter(this.category, this.color);
  final int category;
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
    void line(double x, double y, double a, double b) =>
        canvas.drawLine(Offset(x, y), Offset(a, b), pen);
    switch (category) {
      case 0:
        canvas.drawCircle(const Offset(12, 12), 9, pen);
        line(8, 8.5, 8, 9.5);
        line(16, 8.5, 16, 9.5);
        canvas.drawPath(
          Path()
            ..moveTo(7.5, 14)
            ..quadraticBezierTo(12, 19, 16.5, 14),
          pen,
        );
      case 2:
        canvas.drawOval(const Rect.fromLTWH(6.5, 11, 11, 9), pen);
        for (final p in [
          const Offset(4.5, 10),
          const Offset(9, 5.5),
          const Offset(15, 5.5),
          const Offset(19.5, 10),
        ]) {
          canvas.drawOval(
            Rect.fromCenter(center: p, width: 3.5, height: 4.5),
            pen,
          );
        }
      case 3:
        canvas.drawPath(
          Path()
            ..moveTo(3, 10)
            ..cubicTo(3, 1, 21, 1, 21, 10)
            ..close()
            ..moveTo(3, 17)
            ..lineTo(21, 17)
            ..quadraticBezierTo(21, 21, 18, 21)
            ..lineTo(6, 21)
            ..quadraticBezierTo(3, 21, 3, 17),
          pen,
        );
        line(3, 13.5, 21, 13.5);
        line(8, 7, 8.3, 7);
        line(15, 6.5, 15.3, 6.5);
      case 4:
        canvas.drawPath(
          Path()
            ..moveTo(4, 10)
            ..lineTo(6, 5)
            ..quadraticBezierTo(6.5, 4, 8, 4)
            ..lineTo(16, 4)
            ..quadraticBezierTo(17.5, 4, 18, 5)
            ..lineTo(20, 10),
          pen,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3, 10, 18, 9),
            const Radius.circular(2),
          ),
          pen,
        );
        line(6, 19, 6, 21);
        line(18, 19, 18, 21);
        line(6, 14, 8, 14);
        line(16, 14, 18, 14);
      case 5:
        canvas.drawCircle(const Offset(12, 12), 9, pen);
        line(3, 12, 21, 12);
        line(12, 3, 12, 21);
        canvas.drawPath(
          Path()
            ..moveTo(6, 5.5)
            ..quadraticBezierTo(13, 12, 6, 18.5)
            ..moveTo(18, 5.5)
            ..quadraticBezierTo(11, 12, 18, 18.5),
          pen,
        );
      case 6:
        canvas.drawPath(
          Path()
            ..moveTo(9, 18)
            ..lineTo(9, 16)
            ..cubicTo(9, 14, 5, 13, 5, 9)
            ..cubicTo(5, 0, 19, 0, 19, 9)
            ..cubicTo(19, 13, 15, 14, 15, 16)
            ..lineTo(15, 18)
            ..close(),
          pen,
        );
        line(10, 21, 14, 21);
      case 7:
        canvas.drawPath(
          Path()
            ..moveTo(12, 21)
            ..cubicTo(9, 18, 3, 14, 3, 8)
            ..cubicTo(3, 2, 10, 2, 12, 7)
            ..cubicTo(14, 2, 21, 2, 21, 8)
            ..cubicTo(21, 14, 15, 18, 12, 21)
            ..close(),
          pen,
        );
      case 8:
        line(5, 3, 5, 22);
        canvas.drawPath(
          Path()
            ..moveTo(5, 4)
            ..cubicTo(10, 0, 14, 8, 20, 4)
            ..lineTo(20, 14)
            ..cubicTo(14, 18, 10, 10, 5, 14),
          pen,
        );
    }
  }

  @override
  bool shouldRepaint(_CategoryPainter oldDelegate) =>
      category != oldDelegate.category || color != oldDelegate.color;
}
