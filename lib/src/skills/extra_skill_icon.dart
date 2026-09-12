import 'package:flutter/material.dart';

class ExtraSkillIcon extends StatelessWidget {
  const ExtraSkillIcon(this.name, {super.key});
  final String name;
  static const names = {
    'phone',
    'browser',
    'camera',
    'clipboard',
    'calculator',
    'clock',
    'battery',
    'download',
    'checklist',
    'food',
    'shopping',
    'location',
    'photo',
    'music',
    'chart',
    'translate',
    'mail',
    'health',
    'travel',
  };
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size.square(24),
    painter: _ExtraPainter(
      name,
      Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class _ExtraPainter extends CustomPainter {
  const _ExtraPainter(this.name, this.color);
  final String name;
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
    void box(Rect rect, double radius) => canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      pen,
    );
    switch (name) {
      case 'food':
        canvas.drawPath(
          Path()
            ..moveTo(4, 3)
            ..lineTo(4, 8)
            ..quadraticBezierTo(4, 11, 7, 11)
            ..quadraticBezierTo(10, 11, 10, 8)
            ..lineTo(10, 3),
          pen,
        );
        line(7, 3, 7, 21);
        canvas.drawPath(
          Path()
            ..moveTo(19, 21)
            ..lineTo(19, 3)
            ..quadraticBezierTo(14, 5, 14, 12)
            ..lineTo(19, 12),
          pen,
        );
      case 'shopping':
        box(const Rect.fromLTWH(4, 7, 16, 14), 3);
        canvas.drawPath(
          Path()
            ..moveTo(8, 9)
            ..lineTo(8, 6)
            ..cubicTo(8, 1, 16, 1, 16, 6)
            ..lineTo(16, 9),
          pen,
        );
      case 'location':
        canvas.drawPath(
          Path()
            ..moveTo(12, 22)
            ..cubicTo(9, 18, 4, 14, 4, 10)
            ..cubicTo(4, -1, 20, -1, 20, 10)
            ..cubicTo(20, 14, 15, 18, 12, 22)
            ..close(),
          pen,
        );
        canvas.drawCircle(const Offset(12, 9), 2.5, pen);
      case 'photo':
        box(const Rect.fromLTWH(3, 3, 18, 18), 3);
        canvas.drawCircle(const Offset(8, 8), 1.5, pen);
        canvas.drawPath(
          Path()
            ..moveTo(3, 17)
            ..lineTo(9, 11)
            ..lineTo(14, 16)
            ..lineTo(17, 13)
            ..lineTo(21, 17),
          pen,
        );
      case 'music':
        canvas.drawPath(
          Path()
            ..moveTo(9, 18)
            ..lineTo(9, 5)
            ..lineTo(20, 3)
            ..lineTo(20, 16)
            ..moveTo(9, 9)
            ..lineTo(20, 7),
          pen,
        );
        canvas.drawOval(const Rect.fromLTWH(3, 16, 6, 5), pen);
        canvas.drawOval(const Rect.fromLTWH(14, 14, 6, 5), pen);
      case 'chart':
        canvas.drawPath(
          Path()
            ..moveTo(3, 3)
            ..lineTo(3, 21)
            ..lineTo(21, 21),
          pen,
        );
        line(7, 17, 7, 12);
        line(12, 17, 12, 8);
        line(17, 17, 17, 4);
      case 'translate':
        line(3, 6, 15, 6);
        line(9, 3, 9, 6);
        canvas.drawPath(
          Path()
            ..moveTo(13, 6)
            ..quadraticBezierTo(11, 14, 3, 17)
            ..moveTo(6, 9)
            ..quadraticBezierTo(8, 14, 13, 16)
            ..moveTo(13, 21)
            ..lineTo(17.5, 10)
            ..lineTo(22, 21)
            ..moveTo(15, 17)
            ..lineTo(20, 17),
          pen,
        );
      case 'mail':
        box(const Rect.fromLTWH(2, 5, 20, 14), 3);
        canvas.drawPath(
          Path()
            ..moveTo(3, 7)
            ..lineTo(12, 13)
            ..lineTo(21, 7),
          pen,
        );
      case 'health':
        canvas.drawPath(
          Path()
            ..moveTo(12, 21)
            ..cubicTo(6, 17, 2, 13, 2, 8)
            ..cubicTo(2, 2, 9, 1, 12, 6)
            ..cubicTo(15, 1, 22, 2, 22, 8)
            ..cubicTo(22, 13, 18, 17, 12, 21)
            ..close(),
          pen,
        );
        canvas.drawPath(
          Path()
            ..moveTo(5, 12)
            ..lineTo(9, 12)
            ..lineTo(11, 8)
            ..lineTo(14, 15)
            ..lineTo(16, 12)
            ..lineTo(19, 12),
          pen,
        );
      case 'phone':
        box(const Rect.fromLTWH(6, 2, 12, 20), 3);
        line(10, 5, 14, 5);
        line(11, 19, 13, 19);
      case 'browser':
        box(const Rect.fromLTWH(2, 3, 20, 18), 3);
        line(2, 8, 22, 8);
        line(5, 5.5, 5.5, 5.5);
        line(8, 5.5, 8.5, 5.5);
        line(11, 5.5, 19, 5.5);
      case 'camera':
        canvas.drawPath(
          Path()
            ..moveTo(5, 7)
            ..lineTo(7, 7)
            ..lineTo(9, 4)
            ..lineTo(15, 4)
            ..lineTo(17, 7)
            ..lineTo(19, 7)
            ..quadraticBezierTo(22, 7, 22, 10)
            ..lineTo(22, 18)
            ..quadraticBezierTo(22, 21, 19, 21)
            ..lineTo(5, 21)
            ..quadraticBezierTo(2, 21, 2, 18)
            ..lineTo(2, 10)
            ..quadraticBezierTo(2, 7, 5, 7)
            ..close(),
          pen,
        );
        canvas.drawCircle(const Offset(12, 14), 4, pen);
      case 'clipboard':
        canvas.drawPath(
          Path()
            ..moveTo(8, 5)
            ..lineTo(6, 5)
            ..quadraticBezierTo(4, 5, 4, 7)
            ..lineTo(4, 20)
            ..quadraticBezierTo(4, 22, 6, 22)
            ..lineTo(18, 22)
            ..quadraticBezierTo(20, 22, 20, 20)
            ..lineTo(20, 7)
            ..quadraticBezierTo(20, 5, 18, 5)
            ..lineTo(16, 5),
          pen,
        );
        box(const Rect.fromLTWH(8, 2, 8, 5), 2);
        line(8, 12, 16, 12);
        line(8, 16, 14, 16);
      case 'calculator':
        box(const Rect.fromLTWH(4, 2, 16, 20), 3);
        box(const Rect.fromLTWH(7, 5, 10, 4), 1);
        line(8, 13, 10, 13);
        line(9, 12, 9, 14);
        line(14, 13, 16, 13);
        line(8, 17, 10, 19);
        line(10, 17, 8, 19);
        line(14, 17, 16, 17);
        line(14, 19, 16, 19);
      case 'clock':
        canvas.drawCircle(const Offset(12, 12), 9, pen);
        canvas.drawPath(
          Path()
            ..moveTo(12, 6)
            ..lineTo(12, 12)
            ..lineTo(16, 14),
          pen,
        );
      case 'battery':
        box(const Rect.fromLTWH(2, 6, 18, 12), 2);
        line(22, 10, 22, 14);
        canvas.drawPath(
          Path()
            ..moveTo(12, 8)
            ..lineTo(8, 12)
            ..lineTo(13, 12)
            ..lineTo(10, 16),
          pen,
        );
      case 'download':
        canvas.drawPath(
          Path()
            ..moveTo(12, 3)
            ..lineTo(12, 15)
            ..moveTo(7, 10)
            ..lineTo(12, 15)
            ..lineTo(17, 10)
            ..moveTo(3, 16)
            ..lineTo(3, 19)
            ..quadraticBezierTo(3, 21, 5, 21)
            ..lineTo(19, 21)
            ..quadraticBezierTo(21, 21, 21, 19)
            ..lineTo(21, 16),
          pen,
        );
      case 'checklist':
        for (final y in [5.0, 12.0, 19.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(3, y)
              ..lineTo(5, y + 2)
              ..lineTo(8, y - 2),
            pen,
          );
          line(12, y, 21, y);
        }
      case 'travel':
        box(const Rect.fromLTWH(3, 7, 18, 14), 3);
        canvas.drawPath(
          Path()
            ..moveTo(8, 7)
            ..lineTo(8, 5)
            ..quadraticBezierTo(8, 3, 10, 3)
            ..lineTo(14, 3)
            ..quadraticBezierTo(16, 3, 16, 5)
            ..lineTo(16, 7),
          pen,
        );
        line(8, 7, 8, 21);
        line(16, 7, 16, 21);
    }
  }

  @override
  bool shouldRepaint(_ExtraPainter old) =>
      old.name != name || old.color != color;
}
