import 'package:flutter/material.dart';
import 'wrench_painter.dart';

enum SettingsIconType {
  tools,
  data,
  contacts,
  add,
  memory,
  skills,
  personalization,
  personalInfo,
  balance,
  appearance,
  notifications,
  model,
  device,
  chevron,
  back,
  check,
  tasks,
  filter,
  sort,
  eye,
  eyeOff,
}

class SettingsIcon extends StatelessWidget {
  const SettingsIcon({super.key, required this.type, this.color});

  final SettingsIconType type;
  final Color? color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size.square(24),
    painter: _SettingsIconPainter(
      type,
      color ??
          (Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : const Color(0xff222222)),
    ),
  );
}

class _SettingsIconPainter extends CustomPainter {
  const _SettingsIconPainter(this.type, this.color);
  final Color color;

  final SettingsIconType type;

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
      case SettingsIconType.data:
        canvas.drawOval(const Rect.fromLTWH(4, 3, 16, 6), pen);
        canvas.drawPath(
          Path()
            ..moveTo(4, 6)
            ..lineTo(4, 18)
            ..cubicTo(4, 22, 20, 22, 20, 18)
            ..lineTo(20, 6)
            ..moveTo(4, 12)
            ..cubicTo(4, 16, 20, 16, 20, 12),
          pen,
        );
      case SettingsIconType.eye:
      case SettingsIconType.eyeOff:
        canvas.drawPath(
          Path()
            ..moveTo(2.5, 12)
            ..cubicTo(7, 4.5, 17, 4.5, 21.5, 12)
            ..cubicTo(17, 19.5, 7, 19.5, 2.5, 12),
          pen,
        );
        canvas.drawCircle(const Offset(12, 12), 2.7, pen);
        if (type == SettingsIconType.eyeOff) {
          canvas.drawLine(const Offset(4, 4), const Offset(20, 20), pen);
        }

      case SettingsIconType.tools:
        WrenchPainter(color).paint(canvas, const Size.square(24));
      case SettingsIconType.contacts:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(5, 3, 15, 18),
            const Radius.circular(3),
          ),
          pen,
        );
        canvas.drawLine(const Offset(3, 7), const Offset(6, 7), pen);
        canvas.drawLine(const Offset(3, 12), const Offset(6, 12), pen);
        canvas.drawLine(const Offset(3, 17), const Offset(6, 17), pen);
        canvas.drawCircle(const Offset(12.5, 9), 2.2, pen);
        canvas.drawPath(
          Path()
            ..moveTo(9, 16)
            ..cubicTo(9, 12, 16, 12, 16, 16),
          pen,
        );
      case SettingsIconType.add:
        canvas.drawLine(const Offset(12, 4), const Offset(12, 20), pen);
        canvas.drawLine(const Offset(4, 12), const Offset(20, 12), pen);
      case SettingsIconType.skills:
        canvas.drawPath(
          Path()
            ..moveTo(5, 5)
            ..lineTo(9, 5)
            ..cubicTo(8, 1, 15, 1, 14, 5)
            ..lineTo(18, 5)
            ..quadraticBezierTo(20, 5, 20, 7)
            ..lineTo(20, 10)
            ..cubicTo(16, 9, 16, 16, 20, 15)
            ..lineTo(20, 18)
            ..quadraticBezierTo(20, 20, 18, 20)
            ..lineTo(14, 20)
            ..cubicTo(15, 16, 8, 16, 9, 20)
            ..lineTo(5, 20)
            ..quadraticBezierTo(3, 20, 3, 18)
            ..lineTo(3, 7)
            ..quadraticBezierTo(3, 5, 5, 5)
            ..close(),
          pen,
        );
      case SettingsIconType.personalInfo:
        canvas.drawCircle(const Offset(12, 7), 3.5, pen);
        canvas.drawPath(
          Path()
            ..moveTo(4, 20)
            ..cubicTo(4, 11, 20, 11, 20, 20),
          pen,
        );
      case SettingsIconType.personalization:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(4, 3, 16, 18),
            const Radius.circular(3),
          ),
          pen,
        );
        canvas.drawPath(
          Path()
            ..moveTo(8, 8)
            ..lineTo(16, 8)
            ..moveTo(8, 12)
            ..lineTo(16, 12)
            ..moveTo(8, 16)
            ..lineTo(13, 16),
          pen,
        );
      case SettingsIconType.tasks:
        canvas.drawCircle(const Offset(12, 12), 9, pen);
        canvas.drawPath(
          Path()
            ..moveTo(12, 6)
            ..lineTo(12, 12)
            ..lineTo(8.5, 15.5),
          pen,
        );
      case SettingsIconType.sort:
        canvas.drawLine(const Offset(7, 4), const Offset(7, 20), pen);
        canvas.drawPath(
          Path()
            ..moveTo(4, 7)
            ..lineTo(7, 4)
            ..lineTo(10, 7),
          pen,
        );
        canvas.drawLine(const Offset(17, 4), const Offset(17, 20), pen);
        canvas.drawPath(
          Path()
            ..moveTo(14, 17)
            ..lineTo(17, 20)
            ..lineTo(20, 17),
          pen,
        );
        break;
      case SettingsIconType.filter:
        canvas.drawPath(
          Path()
            ..moveTo(3, 6)
            ..lineTo(21, 6)
            ..moveTo(6, 12)
            ..lineTo(18, 12)
            ..moveTo(10, 18)
            ..lineTo(14, 18),
          pen,
        );
      case SettingsIconType.check:
        canvas.drawPath(
          Path()
            ..moveTo(5, 12)
            ..lineTo(10, 17)
            ..lineTo(19, 7),
          pen,
        );
      case SettingsIconType.balance:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3, 5, 18, 15),
            const Radius.circular(3),
          ),
          pen,
        );
        canvas.drawPath(
          Path()
            ..moveTo(21, 10)
            ..lineTo(16, 10)
            ..quadraticBezierTo(13, 10, 13, 13)
            ..quadraticBezierTo(13, 16, 16, 16)
            ..lineTo(21, 16),
          pen,
        );
        canvas.drawCircle(const Offset(16.5, 13), .8, Paint()..color = color);

      case SettingsIconType.memory:
        canvas.drawPath(
          Path()
            ..moveTo(12, 5)
            ..cubicTo(12, 1.5, 6.5, 1.5, 6.5, 5)
            ..cubicTo(3, 5, 2.2, 9, 4.3, 11)
            ..cubicTo(1.8, 14, 3.5, 17.5, 6.5, 17.5)
            ..cubicTo(6.5, 21.5, 12, 21.5, 12, 18)
            ..lineTo(12, 5)
            ..cubicTo(12, 1.5, 17.5, 1.5, 17.5, 5)
            ..cubicTo(21, 5, 21.8, 9, 19.7, 11)
            ..cubicTo(22.2, 14, 20.5, 17.5, 17.5, 17.5)
            ..cubicTo(17.5, 21.5, 12, 21.5, 12, 18)
            ..moveTo(6.5, 8)
            ..quadraticBezierTo(6.5, 11, 9, 11)
            ..moveTo(17.5, 8)
            ..quadraticBezierTo(17.5, 11, 15, 11)
            ..moveTo(6.5, 17.5)
            ..quadraticBezierTo(6.5, 14.5, 9, 14.5)
            ..moveTo(17.5, 17.5)
            ..quadraticBezierTo(17.5, 14.5, 15, 14.5),
          pen,
        );
      case SettingsIconType.appearance:
        canvas.drawPath(
          Path()
            ..moveTo(10, 3)
            ..cubicTo(5.8, 3.7, 3, 7.2, 3, 11.5)
            ..cubicTo(3, 16.5, 6.8, 20.5, 11.8, 20.5)
            ..cubicTo(16, 20.5, 19.5, 17.8, 20.5, 14)
            ..cubicTo(17.3, 15.3, 13.7, 14.6, 11.4, 12)
            ..cubicTo(9.1, 9.5, 8.6, 6, 10, 3)
            ..close()
            ..moveTo(17.5, 2.5)
            ..quadraticBezierTo(17.5, 6, 21, 6)
            ..quadraticBezierTo(17.5, 6, 17.5, 9.5)
            ..quadraticBezierTo(17.5, 6, 14, 6)
            ..quadraticBezierTo(17.5, 6, 17.5, 2.5)
            ..close(),
          pen,
        );
      case SettingsIconType.notifications:
        canvas.drawPath(
          Path()
            ..moveTo(6, 9)
            ..cubicTo(6, 5.7, 8.2, 3.5, 12, 3.5)
            ..cubicTo(15.8, 3.5, 18, 5.7, 18, 9)
            ..lineTo(18, 12)
            ..cubicTo(18, 14.2, 19.5, 15, 19.5, 16)
            ..quadraticBezierTo(19.5, 17, 18, 17)
            ..lineTo(6, 17)
            ..quadraticBezierTo(4.5, 17, 4.5, 16)
            ..cubicTo(4.5, 15, 6, 14.2, 6, 12)
            ..close()
            ..moveTo(9.5, 20)
            ..quadraticBezierTo(12, 22, 14.5, 20),
          pen,
        );
      case SettingsIconType.model:
        canvas.drawPath(
          Path()
            ..moveTo(4, 7)
            ..lineTo(7, 7)
            ..moveTo(12, 7)
            ..lineTo(20, 7)
            ..moveTo(4, 17)
            ..lineTo(12, 17)
            ..moveTo(17, 17)
            ..lineTo(20, 17),
          pen,
        );
        canvas.drawCircle(const Offset(9.5, 7), 2.5, pen);
        canvas.drawCircle(const Offset(14.5, 17), 2.5, pen);
      case SettingsIconType.device:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(5.5, 2.5, 13, 19),
            const Radius.circular(3),
          ),
          pen,
        );
        canvas.drawLine(const Offset(10, 5.5), const Offset(14, 5.5), pen);
        canvas.drawLine(
          const Offset(10.5, 18.5),
          const Offset(13.5, 18.5),
          pen,
        );
      case SettingsIconType.chevron:
        canvas.drawPath(
          Path()
            ..moveTo(9.5, 7)
            ..lineTo(14.5, 12)
            ..lineTo(9.5, 17),
          pen,
        );
      case SettingsIconType.back:
        canvas.drawPath(
          Path()
            ..moveTo(11, 5)
            ..lineTo(4, 12)
            ..lineTo(11, 19)
            ..moveTo(4, 12)
            ..lineTo(20, 12),
          pen,
        );
    }
  }

  @override
  bool shouldRepaint(_SettingsIconPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}
