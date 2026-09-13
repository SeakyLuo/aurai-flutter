import 'package:flutter/material.dart';

enum AttachmentActionIconType { gallery, camera, file }

class AttachmentActionIcon extends StatelessWidget {
  const AttachmentActionIcon({super.key, required this.type});

  final AttachmentActionIconType type;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size.square(24),
    painter: _AttachmentActionPainter(
      type,
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : Colors.black,
    ),
  );
}

class _AttachmentActionPainter extends CustomPainter {
  const _AttachmentActionPainter(this.type, this.color);

  final AttachmentActionIconType type;
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
    switch (type) {
      case AttachmentActionIconType.file:
        canvas.drawPath(
          Path()
            ..moveTo(14, 3)
            ..lineTo(6, 3)
            ..quadraticBezierTo(4, 3, 4, 5)
            ..lineTo(4, 19)
            ..quadraticBezierTo(4, 21, 6, 21)
            ..lineTo(18, 21)
            ..quadraticBezierTo(20, 21, 20, 19)
            ..lineTo(20, 9)
            ..lineTo(14, 3)
            ..lineTo(14, 9)
            ..lineTo(20, 9),
          pen,
        );
        canvas.drawLine(const Offset(8, 14), const Offset(16, 14), pen);
        canvas.drawLine(const Offset(8, 17), const Offset(13, 17), pen);
      case AttachmentActionIconType.gallery:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3, 3, 18, 18),
            const Radius.circular(4),
          ),
          pen,
        );
        canvas.drawCircle(const Offset(8.2, 8.2), 1.6, pen);
        canvas.drawPath(
          Path()
            ..moveTo(3.5, 17)
            ..lineTo(8.3, 12.2)
            ..quadraticBezierTo(9.1, 11.4, 9.9, 12.2)
            ..lineTo(12.7, 15)
            ..lineTo(15.5, 12.2)
            ..quadraticBezierTo(16.3, 11.4, 17.1, 12.2)
            ..lineTo(20.5, 15.6),
          pen,
        );
      case AttachmentActionIconType.camera:
        canvas.drawPath(
          Path()
            ..moveTo(6, 6.5)
            ..lineTo(7.3, 4.4)
            ..quadraticBezierTo(7.8, 3.5, 9, 3.5)
            ..lineTo(15, 3.5)
            ..quadraticBezierTo(16.2, 3.5, 16.7, 4.4)
            ..lineTo(18, 6.5)
            ..lineTo(18.5, 6.5)
            ..quadraticBezierTo(21.5, 6.5, 21.5, 9.5)
            ..lineTo(21.5, 17.5)
            ..quadraticBezierTo(21.5, 20.5, 18.5, 20.5)
            ..lineTo(5.5, 20.5)
            ..quadraticBezierTo(2.5, 20.5, 2.5, 17.5)
            ..lineTo(2.5, 9.5)
            ..quadraticBezierTo(2.5, 6.5, 5.5, 6.5)
            ..close(),
          pen,
        );
        canvas.drawCircle(const Offset(12, 13.3), 3.7, pen);
    }
  }

  @override
  bool shouldRepaint(_AttachmentActionPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}
