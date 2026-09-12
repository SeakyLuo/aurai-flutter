import 'package:flutter/material.dart';

class SearchAuroraBackground extends StatelessWidget {
  const SearchAuroraBackground({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(
        painter: _AuroraPainter(
          Theme.of(context).brightness == Brightness.dark,
        ),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

class _AuroraPainter extends CustomPainter {
  const _AuroraPainter(this.dark);
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawColor(
      dark ? const Color(0xff15141c) : const Color(0xfffcfcff),
      BlendMode.src,
    );
    void glow(Offset center, double radius, Color color) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    glow(
      Offset(w * .88, h * .22),
      w * .7,
      const Color(0xffb9a7ff).withValues(alpha: dark ? .16 : .18),
    );
    glow(
      Offset(w * .62, h * .30),
      w * .48,
      const Color(0xff9caeff).withValues(alpha: .12),
    );
    glow(
      Offset(-w * .12, h * .77),
      w * .9,
      const Color(0xffb9a7ff).withValues(alpha: .10),
    );
    final top = Path()
      ..moveTo(w * .52, h * .31)
      ..cubicTo(w * .60, h * .19, w * .84, h * .15, w * 1.12, h * .16);
    final bottom = Path()
      ..moveTo(-w * .12, h * .51)
      ..cubicTo(w * .38, h * .57, w * .25, h * .87, w * .88, h * .94);
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = (dark ? const Color(0xffc9bdff) : Colors.white).withValues(
        alpha: dark ? .12 : .85,
      );
    canvas.drawPath(top, pen);
    canvas.drawPath(bottom, pen);
    for (final point in [
      Offset(w * .67, h * .22),
      Offset(w * .90, h * .167),
      Offset(w * .40, h * .77),
    ]) {
      glow(point, 10, Colors.white.withValues(alpha: dark ? .10 : .75));
      canvas.drawCircle(
        point,
        2,
        Paint()..color = Colors.white.withValues(alpha: dark ? .3 : .9),
      );
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) => dark != oldDelegate.dark;
}
