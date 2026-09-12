import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'glass_surface.dart';

class JumpToBottomButton extends StatelessWidget {
  const JumpToBottomButton({
    super.key,
    required this.streaming,
    required this.onPressed,
  });

  final bool streaming;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => GlassSurface(
    radius: 28,
    child: RoundAction(
      label: '回到底部',
      onPressed: onPressed,
      icon: Icons.arrow_downward_rounded,
      iconWidget: streaming ? const _BouncingDots() : null,
    ),
  );
}

class _BouncingDots extends StatefulWidget {
  const _BouncingDots();

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.stop();
      _animation.value = 0;
    } else {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: SizedBox.square(
        dimension: 25,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, _) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(3, (index) {
              final phase = (_animation.value - index * 0.16) % 1;
              final lift = phase < 0.5
                  ? math.sin(phase * math.pi * 2) * 4
                  : 0.0;
              return Transform.translate(
                offset: Offset(0, -lift),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    ),
  );
}
