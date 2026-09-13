import 'package:flutter/material.dart';

class AvatarColorPalette extends StatelessWidget {
  const AvatarColorPalette({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final HSVColor value;
  final ValueChanged<HSVColor> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          const height = 180.0;
          void pick(Offset point) => onChanged(
            value
                .withSaturation((point.dx / width).clamp(0, 1))
                .withValue((1 - point.dy / height).clamp(0, 1)),
          );
          return Semantics(
            label: '调色盘，左右调整颜色浓淡，上下调整明暗',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanDown: (event) => pick(event.localPosition),
              onPanUpdate: (event) => pick(event.localPosition),
              child: SizedBox(
                height: height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white,
                              HSVColor.fromAHSV(1, value.hue, 1, 1).toColor(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: width * value.saturation - 10,
                      top: height * (1 - value.value) - 10,
                      child: _handle(value.toColor()),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      const SizedBox(height: 16),
      LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth - 24;
          void pick(Offset point) => onChanged(
            value.withHue(((point.dx - 12) / width).clamp(0, 1) * 360),
          );
          return Semantics(
            label: '彩虹色条，拖动选择颜色',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanDown: (event) => pick(event.localPosition),
              onPanUpdate: (event) => pick(event.localPosition),
              child: SizedBox(
                height: 44,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 12,
                      right: 12,
                      top: 12,
                      bottom: 12,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: [
                              for (var h = 0; h <= 360; h += 60)
                                HSVColor.fromAHSV(
                                  1,
                                  h.toDouble(),
                                  1,
                                  1,
                                ).toColor(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 2 + width * value.hue / 360,
                      top: 12,
                      child: _handle(
                        HSVColor.fromAHSV(1, value.hue, 1, 1).toColor(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ],
  );

  Widget _handle(Color color) => IgnorePointer(
    child: Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 3, spreadRadius: 1),
        ],
      ),
    ),
  );
}
