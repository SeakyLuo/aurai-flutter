import 'dart:ui';
import 'package:flutter/material.dart';

class ChatHeaderBackground extends StatelessWidget {
  const ChatHeaderBackground({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Stack(
      fit: StackFit.expand,
      children: [
        for (var index = 0; index < 16; index++)
          Positioned(
            top: constraints.maxHeight * index / 16,
            height: constraints.maxHeight / 16,
            left: 0,
            right: 0,
            child: ClipRect(
              child: BackdropFilter(
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
                Theme.of(context).colorScheme.surface.withValues(alpha: .65),
                Theme.of(context).colorScheme.surface.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
