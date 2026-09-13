import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'settings_icon.dart';

const avatarSymbols = <String, String>{
  'app_logo_white': 'App Logo',
  'initial': '首字',
  'person': '人物',
  'spark': '灵感',
  'puzzle': '拼图',
  'memory': '记忆',
  'smile': '笑脸',
  'cat': '猫咪',
  'robot': '机器人',
  'flower': '花朵',
  'sun': '太阳',
  'moon': '月亮',
  'star': '星星',
  'mountain': '山峦',
  'leaf': '叶子',
  'heart': '爱心',
  'planet': '星球',
  'bolt': '闪电',
  'diamond': '晶石',
  'rings': '圆环',
  'waves': '波纹',
};

class AvatarSymbol extends StatelessWidget {
  const AvatarSymbol({super.key, required this.symbol, required this.color});
  final String symbol;
  final Color color;
  @override
  Widget build(BuildContext context) {
    if (symbol == 'app_logo_white') {
      return Image.asset(
        'assets/branding/symbol_white.png',
        width: 24,
        height: 24,
        fit: BoxFit.contain,
      );
    }
    const shared = {
      'person': SettingsIconType.personalInfo,
      'spark': SettingsIconType.personalization,
      'puzzle': SettingsIconType.skills,
      'memory': SettingsIconType.memory,
    };
    final type = shared[symbol];
    return type != null
        ? SettingsIcon(type: type, color: color)
        : CustomPaint(
            size: const Size.square(24),
            painter: _SymbolPainter(symbol, color),
          );
  }
}

class _SymbolPainter extends CustomPainter {
  const _SymbolPainter(this.symbol, this.color);
  final String symbol;
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
    void line(double x, double y, double a, double b) =>
        canvas.drawLine(Offset(x, y), Offset(a, b), pen);
    void circle(double x, double y, double r) =>
        canvas.drawCircle(Offset(x, y), r, pen);
    void path(List<Offset> points, {bool close = false}) {
      final p = Path()..addPolygon(points, close);
      canvas.drawPath(p, pen);
    }

    switch (symbol) {
      case 'smile':
        circle(12, 12, 8);
        circle(9, 10, .4);
        circle(15, 10, .4);
        canvas.drawArc(
          const Rect.fromLTWH(8, 10, 8, 7),
          .2,
          math.pi - .4,
          false,
          pen,
        );
      case 'cat':
        canvas.drawPath(
          Path()
            ..moveTo(5, 10)
            ..lineTo(4, 4)
            ..lineTo(9, 7)
            ..quadraticBezierTo(12, 6, 15, 7)
            ..lineTo(20, 4)
            ..lineTo(19, 10)
            ..cubicTo(23, 23, 1, 23, 5, 10),
          pen,
        );
        circle(9, 12, .4);
        circle(15, 12, .4);
        line(11, 15, 13, 15);
      case 'robot':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(5, 7, 14, 13),
            const Radius.circular(4),
          ),
          pen,
        );
        line(12, 7, 12, 4);
        circle(12, 3, 1);
        line(8, 12, 8, 14);
        line(16, 12, 16, 14);
        line(10, 17, 14, 17);
      case 'flower':
        for (var i = 0; i < 5; i++) {
          final a = i * math.pi * 2 / 5 - math.pi / 2;
          circle(12 + 5 * math.cos(a), 12 + 5 * math.sin(a), 3.6);
        }
        circle(12, 12, 2);
      case 'sun':
        circle(12, 12, 4);
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          line(
            12 + 7 * math.cos(a),
            12 + 7 * math.sin(a),
            12 + 9 * math.cos(a),
            12 + 9 * math.sin(a),
          );
        }
      case 'moon':
        canvas.drawPath(
          Path()
            ..moveTo(15, 4)
            ..cubicTo(4, 1, 0, 17, 11, 20)
            ..quadraticBezierTo(18, 22, 21, 14)
            ..cubicTo(12, 18, 8, 9, 15, 4),
          pen,
        );
      case 'star':
        path([
          for (var i = 0; i < 10; i++)
            Offset(
              12 + (i.isEven ? 9 : 4) * math.cos(i * math.pi / 5 - math.pi / 2),
              12 + (i.isEven ? 9 : 4) * math.sin(i * math.pi / 5 - math.pi / 2),
            ),
        ], close: true);
      case 'mountain':
        path(const [
          Offset(3, 19),
          Offset(10, 5),
          Offset(15, 14),
          Offset(18, 9),
          Offset(22, 19),
        ], close: true);
        path(const [Offset(7, 11), Offset(10, 13), Offset(12, 10)]);
      case 'leaf':
        canvas.drawPath(
          Path()
            ..moveTo(5, 19)
            ..cubicTo(0, 8, 11, 5, 20, 4)
            ..cubicTo(20, 15, 16, 23, 5, 19)
            ..moveTo(4, 21)
            ..lineTo(15, 10),
          pen,
        );
      case 'heart':
        canvas.drawPath(
          Path()
            ..moveTo(12, 20)
            ..cubicTo(-6, 10, 6, -1, 12, 8)
            ..cubicTo(18, -1, 30, 10, 12, 20),
          pen,
        );
      case 'planet':
        circle(12, 12, 6);
        canvas.save();
        canvas.translate(12, 12);
        canvas.rotate(-.5);
        canvas.drawOval(const Rect.fromLTWH(-10, -3.5, 20, 7), pen);
        canvas.restore();
      case 'bolt':
        path(const [
          Offset(14, 3),
          Offset(5, 14),
          Offset(11, 14),
          Offset(10, 21),
          Offset(19, 10),
          Offset(13, 10),
        ], close: true);
      case 'diamond':
        path(const [
          Offset(12, 3),
          Offset(21, 12),
          Offset(12, 21),
          Offset(3, 12),
        ], close: true);
        path(const [
          Offset(12, 7),
          Offset(17, 12),
          Offset(12, 17),
          Offset(7, 12),
        ], close: true);
      case 'rings':
        circle(9, 12, 6);
        circle(15, 12, 6);
      case 'waves':
        for (final y in [7.0, 12.0, 17.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(3, y)
              ..cubicTo(9, y - 7, 15, y + 7, 21, y),
            pen,
          );
        }
    }
  }

  @override
  bool shouldRepaint(_SymbolPainter oldDelegate) =>
      symbol != oldDelegate.symbol || color != oldDelegate.color;
}
