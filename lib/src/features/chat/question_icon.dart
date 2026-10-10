import 'package:flutter/material.dart';

enum QuestionIconType {
  question,
  questionnaire,
  vote,
  close,
  play,
  pause,
  stop,
  undo,
}

class QuestionIcon extends StatelessWidget {
  const QuestionIcon({super.key, required this.type, this.color});
  final QuestionIconType type;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 21,
    child: CustomPaint(
      painter: _QuestionPainter(
        type,
        color ?? Theme.of(context).colorScheme.onSurfaceVariant,
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
      case QuestionIconType.questionnaire:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(4.5, 2.5, 15, 19),
            const Radius.circular(2.5),
          ),
          pen,
        );
        for (final top in const [6.5, 11.0, 15.5]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(7.5, top, 2.5, 2.5),
              const Radius.circular(.6),
            ),
            pen,
          );
          canvas.drawLine(
            Offset(13, top + 1.25),
            Offset(16.5, top + 1.25),
            pen,
          );
        }
      case QuestionIconType.vote:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3, 12, 18, 9),
            const Radius.circular(2),
          ),
          pen,
        );
        canvas.drawPath(
          Path()
            ..moveTo(8, 12)
            ..lineTo(6, 5)
            ..lineTo(15, 2.5)
            ..lineTo(17.5, 12)
            ..moveTo(9, 7)
            ..lineTo(11, 8.5)
            ..lineTo(13.5, 5.5)
            ..moveTo(7, 15)
            ..lineTo(17, 15),
          pen,
        );
      case QuestionIconType.undo:
        canvas.drawPath(
          Path()
            ..moveTo(9, 7)
            ..lineTo(4, 11.5)
            ..lineTo(9, 16)
            ..moveTo(4.5, 11.5)
            ..lineTo(14, 11.5)
            ..cubicTo(18, 11.5, 20.5, 14, 20.5, 18),
          pen,
        );
      case QuestionIconType.stop:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(5, 5, 14, 14),
            const Radius.circular(2),
          ),
          pen,
        );
      case QuestionIconType.pause:
        final fill = Paint()..color = color;
        for (final left in const [6.5, 13.5]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(left, 5.5, 4, 13),
              const Radius.circular(2),
            ),
            fill,
          );
        }
      case QuestionIconType.play:
        canvas.drawPath(
          Path()
            ..moveTo(8, 5)
            ..lineTo(19, 12)
            ..lineTo(8, 19)
            ..close(),
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
