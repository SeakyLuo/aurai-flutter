import 'dart:ui';
import 'package:flutter/material.dart';

class ChatHeaderBackground extends StatelessWidget {
  const ChatHeaderBackground({
    super.key,
    this.surfaceOpacity = .65,
    this.fadeHeight,
  });

  final double surfaceOpacity;
  final double? fadeHeight;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final pixelRatio = MediaQuery.devicePixelRatioOf(context);
      final height = constraints.maxHeight + (fadeHeight ?? 0);
      final fadeStart = fadeHeight == null
          ? 0.0
          : constraints.maxHeight / height;
      double boundary(int index) =>
          (height * index / 16 * pixelRatio).round() / pixelRatio;
      return OverflowBox(
        alignment: Alignment.topCenter,
        minHeight: height,
        maxHeight: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // The final band has zero blur: leave the backdrop untouched there.
            // Adjacent clips share physical-pixel boundaries so no fractional gap
            // appears between the progressively weaker blur bands.
            for (var index = 0; index < 15; index++)
              Positioned(
                top: boundary(index),
                height: boundary(index + 1) - boundary(index),
                left: 0,
                right: 0,
                child: ClipRect(
                  child: BackdropFilter(
                    // Sheets use a saveLayer with a translucent surface. Replace
                    // its sampled pixels instead of compositing their alpha twice.
                    blendMode: BlendMode.src,
                    filter: ImageFilter.blur(
                      sigmaX: 6 * (1 - index / 15),
                      sigmaY: 6 * (1 - index / 15),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: surfaceOpacity),
                    Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: surfaceOpacity),
                    Theme.of(context).colorScheme.surface.withValues(alpha: 0),
                  ],
                  stops: [0, fadeStart, 1],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
