import 'package:flutter/material.dart';

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
    canvas.scale(size.width / 20, size.height / 20);
    canvas.drawCircle(
      const Offset(10, 10),
      9,
      Paint()..color = dark ? const Color(0xff412b33) : const Color(0xfffce9ef),
    );
    canvas.drawCircle(
      const Offset(10, 10),
      9,
      Paint()
        ..color = dark ? const Color(0xff74505d) : const Color(0xfff5cdd9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final pen = Paint()
      ..color = dark ? const Color(0xffe7a1b6) : const Color(0xffd56f90)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(10, 5.5), const Offset(10, 10.7), pen);
    canvas.drawCircle(const Offset(10, 14), .95, pen);
  }

  @override
  bool shouldRepaint(_FailurePainter oldDelegate) => oldDelegate.dark != dark;
}
