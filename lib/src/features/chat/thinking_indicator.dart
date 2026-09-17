import 'package:flutter/material.dart';

class ThinkingIndicator extends StatefulWidget {
  const ThinkingIndicator({
    super.key,
    required this.label,
    this.animate = true,
    this.detail,
    this.leading,
    this.singleLine = false,
    this.fontSize = 15,
  });

  final String label;
  final bool animate;
  final String? detail;
  final Widget? leading;
  final bool singleLine;
  final double fontSize;

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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.leading != null) ...[
              widget.leading!,
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text.rich(
                TextSpan(
                  text: widget.label,
                  children: [
                    if (widget.detail != null)
                      TextSpan(
                        text: '  ${widget.detail}',
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withValues(alpha: .72),
                        ),
                      ),
                  ],
                ),
                textWidthBasis: TextWidthBasis.longestLine,
                maxLines: widget.singleLine ? 1 : null,
                overflow: widget.singleLine ? TextOverflow.ellipsis : null,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  inherit: false,
                  fontSize: widget.fontSize,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        builder: (context, child) =>
            !widget.animate || MediaQuery.disableAnimationsOf(context)
            ? child!
            : ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) {
                  final bandWidth = bounds.width * .35;
                  final left =
                      (bounds.width + bandWidth) * _animation.value - bandWidth;
                  final base = Theme.of(context).colorScheme.onSurfaceVariant;
                  return LinearGradient(
                    colors: [
                      base,
                      Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xfff0eafc)
                          : const Color(0xffc9c6d1),
                      base,
                    ],
                    stops: const [0, .5, 1],
                  ).createShader(
                    Rect.fromLTWH(left, bounds.top, bandWidth, bounds.height),
                  );
                },
                child: child,
              ),
      ),
    ),
  );
}
