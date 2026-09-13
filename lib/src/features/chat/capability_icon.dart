import 'file_tool_icon.dart';
import 'package:flutter/material.dart';

import 'settings_icon.dart';
import 'welcome_icon.dart';

class CapabilityIcon extends StatelessWidget {
  const CapabilityIcon({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 24,
    child: switch (id) {
      'android.network' || 'android.network.capture' => const WelcomeIcon(
        type: WelcomeIconType.network,
      ),
      'android.documents' => const FileToolIcon(type: FileToolIconType.folder),
      'android.observe' => const SettingsIcon(type: SettingsIconType.device),
      'android.notifications.observe' => const SettingsIcon(
        type: SettingsIconType.notifications,
      ),
      _ => CustomPaint(
        painter: _CapabilityPainter(
          id,
          Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    },
  );
}

class _CapabilityPainter extends CustomPainter {
  const _CapabilityPainter(this.id, this.color);
  final String id;
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
    switch (id) {
      case 'screenAccess':
        canvas.drawPath(
          Path()
            ..moveTo(8, 18)
            ..lineTo(5, 18)
            ..quadraticBezierTo(3, 18, 3, 16)
            ..lineTo(3, 5)
            ..quadraticBezierTo(3, 3, 5, 3)
            ..lineTo(17, 3)
            ..quadraticBezierTo(19, 3, 19, 5)
            ..lineTo(19, 8)
            ..moveTo(11, 16)
            ..lineTo(11, 10)
            ..cubicTo(11, 8, 14, 8, 14, 10)
            ..lineTo(14, 14)
            ..lineTo(18, 14.8)
            ..quadraticBezierTo(20, 15.2, 20, 17)
            ..lineTo(19, 21)
            ..lineTo(12, 21)
            ..lineTo(8, 17)
            ..quadraticBezierTo(7, 15, 9, 15)
            ..lineTo(11, 16),
          pen,
        );
      case 'android.accessibility':
      case 'android.apps':
        for (final origin in const [
          Offset(3, 3),
          Offset(14, 3),
          Offset(3, 14),
          Offset(14, 14),
        ]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              origin & const Size(7, 7),
              const Radius.circular(2),
            ),
            pen,
          );
        }
      case 'android.vision':
        canvas.drawPath(
          Path()
            ..moveTo(2, 12)
            ..cubicTo(7, 3, 17, 3, 22, 12)
            ..cubicTo(17, 21, 7, 21, 2, 12)
            ..close(),
          pen,
        );
        canvas.drawCircle(const Offset(12, 12), 3, pen);
      case 'android.permissions':
        canvas.drawPath(
          Path()
            ..moveTo(12, 2.5)
            ..lineTo(20, 6)
            ..lineTo(20, 12)
            ..quadraticBezierTo(19, 18, 12, 21.5)
            ..quadraticBezierTo(5, 18, 4, 12)
            ..lineTo(4, 6)
            ..close(),
          pen,
        );
        canvas.drawPath(
          Path()
            ..moveTo(8, 11.5)
            ..lineTo(11, 14.5)
            ..lineTo(16, 9.5),
          pen,
        );
      case 'android.intents':
        canvas.drawPath(
          Path()
            ..moveTo(10, 4)
            ..lineTo(5, 4)
            ..quadraticBezierTo(3, 4, 3, 6)
            ..lineTo(3, 19)
            ..quadraticBezierTo(3, 21, 5, 21)
            ..lineTo(18, 21)
            ..quadraticBezierTo(20, 21, 20, 19)
            ..lineTo(20, 14)
            ..moveTo(14, 3)
            ..lineTo(21, 3)
            ..lineTo(21, 10)
            ..moveTo(21, 3)
            ..lineTo(11, 13),
          pen,
        );
      case 'android.execution.shizuku':
      case 'android.shell.app_uid':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(2.5, 4, 19, 16),
            const Radius.circular(3),
          ),
          pen,
        );
        canvas.drawPath(
          Path()
            ..moveTo(6, 9)
            ..lineTo(9, 12)
            ..lineTo(6, 15)
            ..moveTo(12, 15)
            ..lineTo(17, 15),
          pen,
        );
      default:
        canvas.drawLine(const Offset(4, 7), const Offset(20, 7), pen);
        canvas.drawLine(const Offset(4, 17), const Offset(20, 17), pen);
        canvas.drawLine(const Offset(9, 4), const Offset(9, 10), pen);
        canvas.drawLine(const Offset(15, 14), const Offset(15, 20), pen);
    }
  }

  @override
  bool shouldRepaint(_CapabilityPainter oldDelegate) =>
      id != oldDelegate.id || color != oldDelegate.color;
}
