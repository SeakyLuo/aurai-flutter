import 'package:flutter/material.dart';

enum AttachmentActionIconType {
  html,
  gallery,
  camera,
  file,
  word,
  excel,
  pdf,
  presentation,
  archive,
  audio,
  video,
  text,
  code,
  package,
  ebook,
  forward,
  download,
  locate,
}

class AttachmentActionIcon extends StatelessWidget {
  const AttachmentActionIcon({super.key, required this.type, this.color});

  final AttachmentActionIconType type;
  final Color? color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size.square(24),
    painter: _AttachmentActionPainter(
      type,
      color ??
          (Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black),
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
      case AttachmentActionIconType.html:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(2, 3, 20, 18),
            const Radius.circular(4),
          ),
          pen,
        );
        canvas.drawPath(
          Path()
            ..moveTo(8.5, 9)
            ..lineTo(5.5, 12)
            ..lineTo(8.5, 15)
            ..moveTo(15.5, 9)
            ..lineTo(18.5, 12)
            ..lineTo(15.5, 15)
            ..moveTo(13, 8)
            ..lineTo(11, 16),
          pen,
        );

      case AttachmentActionIconType.locate:
        canvas.drawCircle(const Offset(12, 12), 7, pen);
        canvas.drawCircle(const Offset(12, 12), 2.5, pen);
        canvas.drawPath(
          Path()
            ..moveTo(12, 2)
            ..lineTo(12, 5)
            ..moveTo(12, 19)
            ..lineTo(12, 22)
            ..moveTo(2, 12)
            ..lineTo(5, 12)
            ..moveTo(19, 12)
            ..lineTo(22, 12),
          pen,
        );
      case AttachmentActionIconType.forward:
        canvas.drawPath(
          Path()
            ..moveTo(5, 17)
            ..cubicTo(5, 10, 10, 8, 17, 8)
            ..moveTo(13, 4)
            ..lineTo(18, 8)
            ..lineTo(13, 12),
          pen,
        );
      case AttachmentActionIconType.download:
        canvas.drawPath(
          Path()
            ..moveTo(12, 3)
            ..lineTo(12, 15)
            ..moveTo(7, 10)
            ..lineTo(12, 15)
            ..lineTo(17, 10)
            ..moveTo(4, 17)
            ..lineTo(4, 20)
            ..lineTo(20, 20)
            ..lineTo(20, 17),
          pen,
        );
      case AttachmentActionIconType.audio:
        canvas.drawPath(
          Path()
            ..moveTo(9, 17)
            ..lineTo(9, 5)
            ..lineTo(20, 3)
            ..lineTo(20, 15)
            ..moveTo(9, 9)
            ..lineTo(20, 7),
          pen,
        );
        canvas.drawOval(const Rect.fromLTWH(3, 15, 6, 5), pen);
        canvas.drawOval(const Rect.fromLTWH(14, 13, 6, 5), pen);
      case AttachmentActionIconType.video:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3, 4, 18, 16),
            const Radius.circular(4),
          ),
          pen,
        );
        canvas.drawPath(
          Path()
            ..moveTo(10, 8)
            ..lineTo(16, 12)
            ..lineTo(10, 16)
            ..close(),
          pen,
        );
      case AttachmentActionIconType.code:
        canvas.drawPath(
          Path()
            ..moveTo(7, 6)
            ..lineTo(2, 12)
            ..lineTo(7, 18)
            ..moveTo(17, 6)
            ..lineTo(22, 12)
            ..lineTo(17, 18)
            ..moveTo(14, 4)
            ..lineTo(10, 20),
          pen,
        );
      case AttachmentActionIconType.package:
        canvas.drawPath(
          Path()
            ..moveTo(12, 2)
            ..lineTo(21, 7)
            ..lineTo(21, 17)
            ..lineTo(12, 22)
            ..lineTo(3, 17)
            ..lineTo(3, 7)
            ..close()
            ..moveTo(3, 7)
            ..lineTo(12, 12)
            ..lineTo(21, 7)
            ..moveTo(12, 12)
            ..lineTo(12, 22)
            ..moveTo(7.5, 4.5)
            ..lineTo(16.5, 9.5)
            ..lineTo(16.5, 14),
          pen,
        );
      case AttachmentActionIconType.ebook:
        canvas.drawPath(
          Path()
            ..moveTo(12, 6)
            ..quadraticBezierTo(7, 2, 2, 4)
            ..lineTo(2, 19)
            ..quadraticBezierTo(7, 17, 12, 21)
            ..quadraticBezierTo(17, 17, 22, 19)
            ..lineTo(22, 4)
            ..quadraticBezierTo(17, 2, 12, 6)
            ..lineTo(12, 21)
            ..moveTo(5, 8)
            ..lineTo(9, 9)
            ..moveTo(15, 9)
            ..lineTo(19, 8),
          pen,
        );
      case AttachmentActionIconType.word:
      case AttachmentActionIconType.excel:
      case AttachmentActionIconType.pdf:
      case AttachmentActionIconType.presentation:
      case AttachmentActionIconType.archive:
      case AttachmentActionIconType.text:
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
        if (type == AttachmentActionIconType.file ||
            type == AttachmentActionIconType.text) {
          canvas.drawLine(const Offset(8, 14), const Offset(16, 14), pen);
          canvas.drawLine(const Offset(8, 17), const Offset(13, 17), pen);
        } else {
          final label = switch (type) {
            AttachmentActionIconType.word => 'W',
            AttachmentActionIconType.excel => 'X',
            AttachmentActionIconType.pdf => 'PDF',
            AttachmentActionIconType.presentation => 'P',
            AttachmentActionIconType.archive => 'ZIP',
            _ => throw StateError('Not a document icon'),
          };
          final text = TextPainter(
            text: TextSpan(
              text: label,
              style: TextStyle(
                color: color,
                fontSize: label.length == 1 ? 9 : 6,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          text.paint(canvas, Offset(12 - text.width / 2, 15 - text.height / 2));
          text.dispose();
        }
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
