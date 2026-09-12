import 'dart:ui';

import 'package:flutter/material.dart';

class WelcomeLogo extends StatelessWidget {
  const WelcomeLogo({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 120,
      height: 96,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            left: -24,
            right: -24,
            top: -20,
            bottom: -20,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    const Color(0xffa481ff).withValues(alpha: .48),
                    const Color(0xffbb9fff).withValues(alpha: .20),
                    const Color(0x00bb9fff),
                  ],
                  stops: const [0, .45, 1],
                ),
              ),
            ),
          ),
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
            child: Image.asset(
              'assets/branding/symbol_white.png',
              width: 120,
              height: 96,
              color: const Color(0xff925aff),
              colorBlendMode: BlendMode.srcIn,
            ),
          ),
          Image.asset(
            'assets/branding/symbol_white.png',
            width: 120,
            height: 96,
            fit: BoxFit.contain,
          ),
        ],
      ),
    ),
  );
}
