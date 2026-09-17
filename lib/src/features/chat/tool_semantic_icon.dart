import 'package:flutter/material.dart';

enum ToolSemanticIconType { imageSearch, appSearch, createFile, shareFile }

class ToolSemanticIcon extends StatelessWidget {
  const ToolSemanticIcon({super.key, required this.type});

  final ToolSemanticIconType type;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size.square(24),
    painter: _ToolSemanticIconPainter(
      type,
      Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class _ToolSemanticIconPainter extends CustomPainter {
  const _ToolSemanticIconPainter(this.type, this.color);

  final ToolSemanticIconType type;
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
      case ToolSemanticIconType.imageSearch:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(2.5, 3, 15, 15),
            const Radius.circular(3),
          ),
          pen,
        );
        canvas.drawCircle(const Offset(7, 7.5), 1.4, pen);
        canvas.drawPath(
          Path()
            ..moveTo(3, 15)
            ..lineTo(7.3, 10.7)
            ..lineTo(11, 14.4)
            ..lineTo(13.2, 12.2)
            ..lineTo(16.8, 15.8),
          pen,
        );
        canvas.drawCircle(const Offset(17.5, 17.5), 3.5, pen);
        canvas.drawLine(
          const Offset(20.1, 20.1),
          const Offset(22, 22),
          pen,
        );
      case ToolSemanticIconType.appSearch:
        for (final origin in const [
          Offset(3, 3),
          Offset(12, 3),
          Offset(3, 12),
        ]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              origin & const Size(6.5, 6.5),
              const Radius.circular(2),
            ),
            pen,
          );
        }
        canvas.drawCircle(const Offset(16.5, 16.5), 3.5, pen);
        canvas.drawLine(
          const Offset(19.1, 19.1),
          const Offset(21.5, 21.5),
          pen,
        );
      case ToolSemanticIconType.createFile:
        _document(canvas, pen);
        canvas.drawLine(const Offset(12, 16), const Offset(18, 16), pen);
        canvas.drawLine(const Offset(15, 13), const Offset(15, 19), pen);
      case ToolSemanticIconType.shareFile:
        _document(canvas, pen);
        canvas.drawPath(
          Path()
            ..moveTo(11, 16)
            ..lineTo(20, 7)
            ..moveTo(14, 7)
            ..lineTo(20, 7)
            ..lineTo(20, 13),
          pen,
        );
    }
  }

  void _document(Canvas canvas, Paint pen) {
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
        ..lineTo(13.5, 3)
        ..lineTo(13.5, 9.5)
        ..lineTo(20, 9.5),
      pen,
    );
  }

  @override
  bool shouldRepaint(_ToolSemanticIconPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}
