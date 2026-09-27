import 'package:flutter/material.dart';

class ExtraSkillIcon extends StatelessWidget {
  const ExtraSkillIcon(this.name, {super.key, this.color});
  final String name;
  final Color? color;
  static const names = {
    'phone',
    'browser',
    'window',
    'camera',
    'clipboard',
    'calculator',
    'clock',
    'battery',
    'download',
    'checklist',
    'news',
    'calendar',
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
    'terminal',
    'database',
    'api',
    'cloud',
    'link',
    'lock',
    'key',
    'robot',
    'bug',
    'automation',
    'palette',
    'science',
    'brain',
  };
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size.square(24),
    painter: _ExtraPainter(
      name,
      color ?? Theme.of(context).colorScheme.onSurfaceVariant,
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
      case 'news':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3, 4, 18, 16),
            const Radius.circular(2.5),
          ),
          pen,
        );
        box(const Rect.fromLTWH(6, 7, 5, 5), 1);
        line(14, 7, 18, 7);
        line(14, 10, 18, 10);
        line(6, 15, 18, 15);
        line(6, 18, 15, 18);
      case 'calendar':
        box(const Rect.fromLTWH(3, 4.5, 18, 17), 3);
        line(3, 9, 21, 9);
        line(8, 2.5, 8, 6.5);
        line(16, 2.5, 16, 6.5);
        for (final point in const [
          Offset(8, 13),
          Offset(12, 13),
          Offset(16, 13),
          Offset(8, 17),
          Offset(12, 17),
          Offset(16, 17),
        ]) {
          canvas.drawCircle(point, .55, Paint()..color = color);
        }
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
        canvas.drawCircle(const Offset(12, 12), 9, pen);
        canvas.drawOval(const Rect.fromLTRB(8, 3, 16, 21), pen);
        canvas.drawPath(
          Path()
            ..moveTo(4.2, 8)
            ..quadraticBezierTo(12, 10.5, 19.8, 8)
            ..moveTo(4.2, 16)
            ..quadraticBezierTo(12, 13.5, 19.8, 16),
          pen,
        );
      case 'window':
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
      case 'terminal':
        box(const Rect.fromLTWH(2, 4, 20, 16), 3);
        canvas.drawPath(
          Path()
            ..moveTo(6, 9)
            ..lineTo(9, 12)
            ..lineTo(6, 15)
            ..moveTo(12, 15)
            ..lineTo(17, 15),
          pen,
        );
      case 'database':
        canvas.drawOval(const Rect.fromLTWH(3, 3, 18, 6), pen);
        canvas.drawPath(
          Path()
            ..moveTo(3, 6)
            ..lineTo(3, 18)
            ..cubicTo(3, 22, 21, 22, 21, 18)
            ..lineTo(21, 6)
            ..moveTo(3, 12)
            ..cubicTo(3, 16, 21, 16, 21, 12),
          pen,
        );
      case 'api':
        for (final point in const [
          Offset(5, 12),
          Offset(12, 5),
          Offset(19, 12),
          Offset(12, 19),
        ]) {
          canvas.drawCircle(point, 2.5, pen);
        }
        line(6.8, 10.2, 10.2, 6.8);
        line(13.8, 6.8, 17.2, 10.2);
        line(17.2, 13.8, 13.8, 17.2);
        line(10.2, 17.2, 6.8, 13.8);
      case 'cloud':
        canvas.drawPath(
          Path()
            ..moveTo(7, 19)
            ..cubicTo(1, 19, 1, 11, 7, 10)
            ..cubicTo(8, 3, 18, 3, 19, 10)
            ..cubicTo(24, 11, 23, 19, 18, 19)
            ..close(),
          pen,
        );
      case 'link':
        canvas.drawPath(
          Path()
            ..moveTo(9, 15)
            ..lineTo(7, 17)
            ..cubicTo(3, 21, 0, 16, 3, 12)
            ..lineTo(5, 7)
            ..cubicTo(8, 4, 11, 5, 13, 7)
            ..moveTo(15, 9)
            ..lineTo(17, 7)
            ..cubicTo(21, 3, 24, 8, 21, 12)
            ..lineTo(19, 17)
            ..cubicTo(16, 20, 13, 19, 11, 17)
            ..moveTo(8, 16)
            ..lineTo(16, 8),
          pen,
        );
      case 'lock':
        box(const Rect.fromLTWH(4, 10, 16, 11), 3);
        canvas.drawPath(
          Path()
            ..moveTo(8, 10)
            ..lineTo(8, 7)
            ..cubicTo(8, 1, 16, 1, 16, 7)
            ..lineTo(16, 10),
          pen,
        );
        canvas.drawCircle(const Offset(12, 15), 1.2, pen);
        line(12, 16.2, 12, 18);
      case 'key':
        canvas.drawCircle(const Offset(7, 9), 4, pen);
        canvas.drawPath(
          Path()
            ..moveTo(10, 12)
            ..lineTo(20, 22)
            ..moveTo(15, 17)
            ..lineTo(18, 14)
            ..moveTo(18, 20)
            ..lineTo(21, 17),
          pen,
        );
      case 'robot':
        box(const Rect.fromLTWH(3, 7, 18, 14), 4);
        line(12, 3, 12, 7);
        canvas.drawCircle(const Offset(12, 2.5), 1.2, pen);
        canvas.drawCircle(const Offset(8, 13), 1.2, pen);
        canvas.drawCircle(const Offset(16, 13), 1.2, pen);
        line(8, 17, 16, 17);
      case 'bug':
        canvas.drawOval(const Rect.fromLTWH(7, 5, 10, 16), pen);
        line(9, 5, 7, 2);
        line(15, 5, 17, 2);
        line(7, 9, 3, 7);
        line(17, 9, 21, 7);
        line(7, 13, 3, 13);
        line(17, 13, 21, 13);
        line(7, 17, 3, 20);
        line(17, 17, 21, 20);
        line(7, 11, 17, 11);
      case 'automation':
        canvas.drawCircle(const Offset(12, 12), 3, pen);
        canvas.drawPath(
          Path()
            ..moveTo(4, 10)
            ..cubicTo(5, 5, 10, 2, 15, 4)
            ..lineTo(18, 6)
            ..moveTo(15, 2)
            ..lineTo(18, 6)
            ..lineTo(14, 7)
            ..moveTo(20, 14)
            ..cubicTo(19, 19, 14, 22, 9, 20)
            ..lineTo(6, 18)
            ..moveTo(9, 22)
            ..lineTo(6, 18)
            ..lineTo(10, 17),
          pen,
        );
      case 'palette':
        canvas.drawPath(
          Path()
            ..moveTo(12, 3)
            ..cubicTo(3, 3, 0, 13, 5, 19)
            ..cubicTo(8, 23, 12, 19, 11, 17)
            ..cubicTo(10, 14, 14, 13, 17, 15)
            ..cubicTo(20, 17, 23, 14, 21, 9)
            ..cubicTo(20, 5, 16, 3, 12, 3)
            ..close(),
          pen,
        );
        for (final point in const [
          Offset(7, 9),
          Offset(11, 6.5),
          Offset(16, 7.5),
        ]) {
          canvas.drawCircle(point, 1, pen);
        }
      case 'science':
        canvas.drawPath(
          Path()
            ..moveTo(9, 3)
            ..lineTo(15, 3)
            ..moveTo(10, 3)
            ..lineTo(10, 9)
            ..lineTo(4, 19)
            ..quadraticBezierTo(3, 21, 6, 21)
            ..lineTo(18, 21)
            ..quadraticBezierTo(21, 21, 20, 19)
            ..lineTo(14, 9)
            ..lineTo(14, 3)
            ..moveTo(7, 16)
            ..quadraticBezierTo(12, 13, 17, 16),
          pen,
        );
      case 'brain':
        canvas.drawPath(
          Path()
            ..moveTo(12, 5)
            ..cubicTo(10, 1, 5, 3, 6, 7)
            ..cubicTo(2, 7, 2, 13, 5, 14)
            ..cubicTo(3, 18, 7, 22, 11, 19)
            ..lineTo(12, 5)
            ..moveTo(12, 5)
            ..cubicTo(14, 1, 19, 3, 18, 7)
            ..cubicTo(22, 7, 22, 13, 19, 14)
            ..cubicTo(21, 18, 17, 22, 13, 19)
            ..lineTo(12, 5)
            ..moveTo(6, 10)
            ..cubicTo(9, 9, 10, 11, 10, 13)
            ..moveTo(18, 10)
            ..cubicTo(15, 9, 14, 11, 14, 13),
          pen,
        );
    }
  }

  @override
  bool shouldRepaint(_ExtraPainter old) =>
      old.name != name || old.color != color;
}
