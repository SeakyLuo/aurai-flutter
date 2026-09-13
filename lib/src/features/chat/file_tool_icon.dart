import 'package:flutter/material.dart';

enum FileToolIconType { folder, read, document }

class FileToolIcon extends StatelessWidget {
  const FileToolIcon({super.key, required this.type});
  final FileToolIconType type;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size.square(24),
    painter: _FileToolPainter(
      type,
      Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class _FileToolPainter extends CustomPainter {
  const _FileToolPainter(this.type, this.color);
  final FileToolIconType type;
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
      case FileToolIconType.document:
        canvas.drawPath(
          Path()
            ..moveTo(13.5, 3)
            ..lineTo(6, 3)
            ..quadraticBezierTo(4, 3, 4, 5)
            ..lineTo(4, 19)
            ..quadraticBezierTo(4, 21, 6, 21)
            ..lineTo(18, 21)
            ..quadraticBezierTo(20, 21, 20, 19)
            ..lineTo(20, 9.5)
            ..close()
            ..moveTo(13.5, 3)
            ..lineTo(13.5, 9.5)
            ..lineTo(20, 9.5)
            ..moveTo(8, 13)
            ..lineTo(16, 13)
            ..moveTo(8, 17)
            ..lineTo(14, 17),
          pen,
        );
      case FileToolIconType.folder:
        canvas.drawPath(
          Path()
            ..moveTo(3, 8)
            ..lineTo(3, 6.3)
            ..quadraticBezierTo(3, 3.5, 5.8, 3.5)
            ..lineTo(8.3, 3.5)
            ..quadraticBezierTo(9.2, 3.5, 9.9, 4.2)
            ..lineTo(11.4, 5.5)
            ..lineTo(18.2, 5.5)
            ..quadraticBezierTo(21, 5.5, 21, 8.3)
            ..lineTo(21, 17.7)
            ..quadraticBezierTo(21, 20.5, 18.2, 20.5)
            ..lineTo(5.8, 20.5)
            ..quadraticBezierTo(3, 20.5, 3, 17.7)
            ..close()
            ..moveTo(3, 10)
            ..lineTo(21, 10),
          pen,
        );
      case FileToolIconType.read:
        canvas.drawPath(
          Path()
            ..moveTo(12, 21)
            ..cubicTo(9, 18.7, 5.6, 18, 2.8, 18.5)
            ..lineTo(2.8, 5.5)
            ..quadraticBezierTo(4.3, 5.2, 6, 5.6)
            ..moveTo(6, 15.8)
            ..lineTo(6, 2.8)
            ..cubicTo(8.5, 2.8, 10.5, 4.4, 12, 6)
            ..lineTo(12, 21)
            ..cubicTo(15, 18.7, 18.4, 18, 21.2, 18.5)
            ..lineTo(21.2, 5.5)
            ..cubicTo(17.8, 4.8, 14.8, 5.5, 12, 7.5)
            ..moveTo(6, 15.8)
            ..quadraticBezierTo(9.4, 16.2, 12, 21),
          pen,
        );
    }
  }

  @override
  bool shouldRepaint(_FileToolPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}
