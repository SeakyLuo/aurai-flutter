import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StartupBrand extends StatelessWidget {
  const StartupBrand({super.key});

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light.copyWith(
      statusBarColor: const Color(0xff100c20),
      systemNavigationBarColor: const Color(0xff100c20),
    ),
    child: Scaffold(
      backgroundColor: const Color(0xff100c20),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: ExcludeSemantics(
              child: SizedBox(
                width: 240,
                height: 208,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              Color(0x709e75ff),
                              Color(0x269e75ff),
                              Color(0x009e75ff),
                            ],
                            stops: [0, 0.45, 1],
                          ),
                        ),
                      ),
                    ),
                    ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Image.asset(
                        'assets/branding/symbol_white.png',
                        width: 144,
                        height: 112,
                        fit: BoxFit.contain,
                        color: const Color(0xffb396ff),
                        colorBlendMode: BlendMode.srcIn,
                      ),
                    ),
                    Image.asset(
                      'assets/branding/symbol_white.png',
                      width: 144,
                      height: 112,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 48,
            child: SafeArea(
              top: false,
              child: Center(
                child: Image.asset(
                  'assets/branding/wordmark_white.png',
                  width: 160,
                  height: 53,
                  fit: BoxFit.contain,
                  semanticLabel: 'Aurai',
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
