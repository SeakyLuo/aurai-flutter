import 'package:flutter/material.dart';

enum SettingsIconType { model, device, chevron, back }

class SettingsIcon extends StatelessWidget {
  const SettingsIcon({super.key, required this.type});

  final SettingsIconType type;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size.square(24),
    painter: _SettingsIconPainter(
      type,
      Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class _SettingsIconPainter extends CustomPainter {
  const _SettingsIconPainter(this.type, this.color);
  final Color color;

  final SettingsIconType type;

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
      case SettingsIconType.model:
        canvas.drawPath(
          Path()
            ..moveTo(4, 7)
            ..lineTo(7, 7)
            ..moveTo(12, 7)
            ..lineTo(20, 7)
            ..moveTo(4, 17)
            ..lineTo(12, 17)
            ..moveTo(17, 17)
            ..lineTo(20, 17),
          pen,
        );
        canvas.drawCircle(const Offset(9.5, 7), 2.5, pen);
        canvas.drawCircle(const Offset(14.5, 17), 2.5, pen);
      case SettingsIconType.device:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(5.5, 2.5, 13, 19),
            const Radius.circular(3),
          ),
          pen,
        );
        canvas.drawLine(const Offset(10, 5.5), const Offset(14, 5.5), pen);
        canvas.drawLine(
          const Offset(10.5, 18.5),
          const Offset(13.5, 18.5),
          pen,
        );
      case SettingsIconType.chevron:
        canvas.drawPath(
          Path()
            ..moveTo(9.5, 7)
            ..lineTo(14.5, 12)
            ..lineTo(9.5, 17),
          pen,
        );
      case SettingsIconType.back:
        canvas.drawPath(
          Path()
            ..moveTo(11, 5)
            ..lineTo(4, 12)
            ..lineTo(11, 19)
            ..moveTo(4, 12)
            ..lineTo(20, 12),
          pen,
        );
    }
  }

  @override
  bool shouldRepaint(_SettingsIconPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}
