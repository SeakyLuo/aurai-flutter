import 'package:flutter/material.dart';

enum QuestionIconType { question, close, userAction, play, pause }

class QuestionIcon extends StatelessWidget {
  const QuestionIcon({super.key, required this.type});
  final QuestionIconType type;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 21,
    child: CustomPaint(
      painter: _QuestionPainter(
        type,
        Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class _QuestionPainter extends CustomPainter {
  const _QuestionPainter(this.type, this.color);
  final QuestionIconType type;
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
      case QuestionIconType.pause:
        canvas.drawLine(const Offset(8, 5), const Offset(8, 19), pen);
        canvas.drawLine(const Offset(16, 5), const Offset(16, 19), pen);
      case QuestionIconType.play:
        canvas.drawPath(
          Path()
            ..moveTo(8, 5)
            ..lineTo(19, 12)
            ..lineTo(8, 19)
            ..close(),
          pen,
        );
      case QuestionIconType.userAction:
        canvas.drawCircle(const Offset(9, 6), 3, pen);
        canvas.drawPath(
          Path()
            ..moveTo(3, 20)
            ..lineTo(3, 17.5)
            ..cubicTo(3, 13.6, 7.4, 11.6, 11, 13),
          pen,
        );
        canvas.drawCircle(const Offset(17, 17), 4.5, pen);
        canvas.drawPath(
          Path()
            ..moveTo(17, 14.5)
            ..lineTo(17, 17)
            ..lineTo(19, 18),
          pen,
        );
      case QuestionIconType.question:
        canvas.drawPath(
          Path()
            ..moveTo(8, 20)
            ..lineTo(3.5, 21)
            ..lineTo(4.5, 16.5)
            ..cubicTo(0, 9.5, 5, 2.5, 12, 2.5)
            ..cubicTo(17.3, 2.5, 21.5, 6.6, 21.5, 12)
            ..cubicTo(21.5, 19, 14, 23, 8, 20)
            ..moveTo(9.3, 9)
            ..cubicTo(9.3, 5.9, 15, 5.9, 15, 9)
            ..cubicTo(15, 11.1, 12, 11.1, 12, 13.4),
          pen,
        );
        canvas.drawCircle(const Offset(12, 16.4), .85, Paint()..color = color);
      case QuestionIconType.close:
        canvas.drawPath(
          Path()
            ..moveTo(6, 6)
            ..lineTo(18, 18)
            ..moveTo(18, 6)
            ..lineTo(6, 18),
          pen,
        );
    }
  }

  @override
  bool shouldRepaint(_QuestionPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}
