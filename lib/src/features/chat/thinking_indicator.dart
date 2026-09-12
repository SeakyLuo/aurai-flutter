import 'package:flutter/material.dart';

class ThinkingIndicator extends StatefulWidget {
  const ThinkingIndicator({
    super.key,
    required this.label,
    this.animate = true,
  });

  final String label;
  final bool animate;

  @override
  State<ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAnimation();
  }

  @override
  void didUpdateWidget(ThinkingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) _updateAnimation();
  }

  void _updateAnimation() {
    if (!widget.animate || MediaQuery.disableAnimationsOf(context)) {
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
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: _animation,
        child: Text(
          widget.label,
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        builder: (context, child) => ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) =>
              LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Theme.of(context).colorScheme.onSurfaceVariant,
                  Theme.of(context).colorScheme.onSurfaceVariant,
                  Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xfff0eafc)
                      : const Color(0xffc9c6d1),
                  Theme.of(context).colorScheme.onSurfaceVariant,
                  Theme.of(context).colorScheme.onSurfaceVariant,
                ],
                stops: [0, 0.28, 0.5, 0.72, 1],
              ).createShader(
                bounds.shift(
                  Offset(bounds.width * (_animation.value * 2 - 1), 0),
                ),
              ),
          child: child,
        ),
      ),
    ),
  );
}
