import 'package:flutter/material.dart';

enum ConversationMenuIconType {
  pin,
  unpin,
  rename,
  recall,
  archive,
  unarchive,
  delete,
}

class ConversationMenuIcon extends StatelessWidget {
  const ConversationMenuIcon({
    super.key,
    required this.type,
    required this.color,
  });

  final ConversationMenuIconType type;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size.square(21),
    painter: _MenuIconPainter(type, color),
  );
}

class _MenuIconPainter extends CustomPainter {
  const _MenuIconPainter(this.type, this.color);

  final ConversationMenuIconType type;
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
      case ConversationMenuIconType.pin:
      case ConversationMenuIconType.unpin:
        canvas.save();
        canvas.translate(12, 12);
        canvas.rotate(0.65);
        canvas.translate(-12, -12);
        canvas.drawPath(
          Path()
            ..moveTo(8, 3.5)
            ..lineTo(16, 3.5)
            ..moveTo(9, 3.5)
            ..lineTo(9, 9)
            ..quadraticBezierTo(9, 10, 7.5, 11.2)
            ..quadraticBezierTo(6, 12.4, 6, 14)
            ..lineTo(18, 14)
            ..quadraticBezierTo(18, 12.4, 16.5, 11.2)
            ..quadraticBezierTo(15, 10, 15, 9)
            ..lineTo(15, 3.5)
            ..moveTo(12, 14)
            ..lineTo(12, 21),
          pen,
        );
        canvas.restore();
        if (type == ConversationMenuIconType.unpin) {
          canvas.drawLine(const Offset(4, 4), const Offset(20, 20), pen);
        }
      case ConversationMenuIconType.rename:
        canvas.drawPath(
          Path()
            ..moveTo(14.8, 4.7)
            ..quadraticBezierTo(17.3, 2.2, 19.8, 4.7)
            ..quadraticBezierTo(22.3, 7.2, 19.8, 9.7)
            ..lineTo(9.1, 20.4)
            ..lineTo(3.5, 21)
            ..lineTo(4.1, 15.4)
            ..close()
            ..moveTo(13.2, 6.3)
            ..lineTo(18.2, 11.3),
          pen,
        );
      case ConversationMenuIconType.recall:
        canvas.drawPath(
          Path()
            ..moveTo(8, 4.5)
            ..lineTo(3.5, 9)
            ..lineTo(8, 13.5)
            ..moveTo(3.5, 9)
            ..lineTo(14, 9)
            ..cubicTo(22, 9, 22, 19.5, 14, 19.5)
            ..lineTo(10, 19.5),
          pen,
        );
      case ConversationMenuIconType.archive:
      case ConversationMenuIconType.unarchive:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3, 3.5, 18, 4.5),
            const Radius.circular(1.5),
          ),
          pen,
        );
        canvas.drawPath(
          Path()
            ..moveTo(4.5, 8)
            ..lineTo(4.5, 18.5)
            ..quadraticBezierTo(4.5, 20.5, 6.5, 20.5)
            ..lineTo(17.5, 20.5)
            ..quadraticBezierTo(19.5, 20.5, 19.5, 18.5)
            ..lineTo(19.5, 8),
          pen,
        );
        if (type == ConversationMenuIconType.archive) {
          canvas.drawLine(const Offset(9, 12), const Offset(15, 12), pen);
        } else {
          canvas.drawPath(
            Path()
              ..moveTo(9, 14)
              ..lineTo(12, 11)
              ..lineTo(15, 14)
              ..moveTo(12, 11)
              ..lineTo(12, 17),
            pen,
          );
        }
      case ConversationMenuIconType.delete:
        canvas.drawPath(
          Path()
            ..moveTo(3.5, 6.5)
            ..lineTo(20.5, 6.5)
            ..moveTo(8.5, 6.5)
            ..lineTo(8.5, 4.5)
            ..quadraticBezierTo(8.5, 3, 10, 3)
            ..lineTo(14, 3)
            ..quadraticBezierTo(15.5, 3, 15.5, 4.5)
            ..lineTo(15.5, 6.5)
            ..moveTo(5.5, 6.5)
            ..lineTo(6.2, 18.6)
            ..quadraticBezierTo(6.3, 21, 8.7, 21)
            ..lineTo(15.3, 21)
            ..quadraticBezierTo(17.7, 21, 17.8, 18.6)
            ..lineTo(18.5, 6.5)
            ..moveTo(9.7, 10.5)
            ..lineTo(10, 16.7)
            ..moveTo(14.3, 10.5)
            ..lineTo(14, 16.7),
          pen,
        );
    }
  }

  @override
  bool shouldRepaint(_MenuIconPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}
