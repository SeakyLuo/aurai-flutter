import 'package:flutter/material.dart';

import '../features/chat/glass_surface.dart';

/// A neutral glass floor, visually separate from the light chat sheet above it.
class MiniappHomeSurface extends StatelessWidget {
  const MiniappHomeSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return GlassSurface(
      radius: 0,
      shadowOpacity: 0,
      gradientColors: dark
          ? const [Color(0xff29292b), Color(0xff212123), Color(0xff272729)]
          : const [Color(0xfff2f3f5), Color(0xffe8eaed), Color(0xffeff0f2)],
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(painter: _MiniappTopLight(dark)),
              ),
            ),
          ),
          Theme(
            data: theme.copyWith(
              colorScheme: theme.colorScheme.copyWith(
                surface: dark
                    ? const Color(0xff272729)
                    : const Color(0xffeff0f2),
              ),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// The empty-chat purple light enters from above, leaving the app grid neutral.
class _MiniappTopLight extends CustomPainter {
  const _MiniappTopLight(this.dark);
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final spread = size.width.clamp(0.0, 640.0);
    canvas.save();
    canvas.translate(size.width * .92, -24);
    canvas.scale(spread * .82, spread * .43);
    canvas.drawCircle(
      Offset.zero,
      1,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xffad94f5).withValues(alpha: dark ? .42 : .48),
            const Color(0xffad94f5).withValues(alpha: dark ? .16 : .18),
            const Color(0x00ad94f5),
          ],
          stops: const [0, .48, 1],
        ).createShader(const Rect.fromLTRB(-1, -1, 1, 1)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MiniappTopLight oldDelegate) => dark != oldDelegate.dark;
}
