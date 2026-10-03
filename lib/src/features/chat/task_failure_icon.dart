import 'package:flutter/material.dart';
import '../../app/global_ui.dart';

class TaskFailureIcon extends StatelessWidget {
  const TaskFailureIcon({super.key, this.size = 16});
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _FailurePainter(Theme.of(context).brightness == Brightness.dark),
  );
}

class _FailurePainter extends CustomPainter {
  const _FailurePainter(this.dark);
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final pen = Paint()
      ..color = dark ? GlobalUI.darkWarningRed : GlobalUI.warningRed
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawCircle(const Offset(12, 12), 9, pen);
    canvas.drawLine(const Offset(12, 7), const Offset(12, 12.5), pen);
    canvas.drawCircle(
      const Offset(12, 16.5),
      .95,
      pen..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_FailurePainter oldDelegate) => oldDelegate.dark != dark;
}
