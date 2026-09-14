import 'package:flutter/material.dart';

enum HtmlGameIconType { game, play, expand, close }

class HtmlGameIcon extends StatelessWidget {
  const HtmlGameIcon(this.type, {super.key});
  final HtmlGameIconType type;
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size.square(24),
    painter: _Painter(type, Theme.of(context).colorScheme.onSurfaceVariant),
  );
}

class _Painter extends CustomPainter {
  _Painter(this.type, this.color);
  final HtmlGameIconType type;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (type) {
      case HtmlGameIconType.game:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3, 6, 18, 13),
            const Radius.circular(5),
          ),
          pen,
        );
        canvas.drawLine(const Offset(6, 12), const Offset(11, 12), pen);
        canvas.drawLine(const Offset(8.5, 9.5), const Offset(8.5, 14.5), pen);
        canvas.drawCircle(const Offset(16, 10.5), 1, pen);
        canvas.drawCircle(const Offset(18, 14), 1, pen);
      case HtmlGameIconType.play:
        canvas.drawPath(
          Path()
            ..moveTo(8, 5)
            ..lineTo(19, 12)
            ..lineTo(8, 19)
            ..close(),
          pen,
        );
      case HtmlGameIconType.close:
        canvas.drawLine(const Offset(6, 6), const Offset(18, 18), pen);
        canvas.drawLine(const Offset(18, 6), const Offset(6, 18), pen);
      case HtmlGameIconType.expand:
        canvas.drawPath(
          Path()
            ..moveTo(9, 4)
            ..lineTo(4, 4)
            ..lineTo(4, 9)
            ..moveTo(15, 4)
            ..lineTo(20, 4)
            ..lineTo(20, 9)
            ..moveTo(4, 15)
            ..lineTo(4, 20)
            ..lineTo(9, 20)
            ..moveTo(15, 20)
            ..lineTo(20, 20)
            ..lineTo(20, 15),
          pen,
        );
    }
  }

  @override
  bool shouldRepaint(_Painter oldDelegate) =>
      type != oldDelegate.type || color != oldDelegate.color;
}
