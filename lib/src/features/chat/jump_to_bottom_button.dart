import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';

import 'glass_surface.dart';

class JumpToBottomButton extends StatelessWidget {
  const JumpToBottomButton({
    super.key,
    required this.streaming,
    required this.onPressed,
    this.visible = true,
  });

  final bool streaming;
  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final visibility = context
        .dependOnInheritedWidgetOfExactType<_JumpVisibility>()!
        .notifier!;
    return ValueListenableBuilder<bool>(
      valueListenable: visibility,
      builder: (context, scrolling, child) {
        final shown = visible && scrolling;
        final duration = MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220);
        return IgnorePointer(
          ignoring: !shown,
          child: ExcludeSemantics(
            excluding: !shown,
            child: AnimatedOpacity(
              opacity: shown ? 1 : 0,
              duration: duration,
              curve: Curves.easeOutCubic,
              child: AnimatedSlide(
                offset: shown ? Offset.zero : const Offset(0, .2),
                duration: duration,
                curve: Curves.easeOutCubic,
                child: AnimatedScale(
                  scale: shown ? 1 : .9,
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
      child: GlassSurface(
        radius: 28,
        child: RoundAction(
          label: '回到底部',
          onPressed: onPressed,
          icon: Icons.arrow_downward_rounded,
          iconWidget: streaming ? const _BouncingDots() : null,
        ),
      ),
    );
  }
}

/// Keeps gesture visibility even before scrolling reveals the jump button.
class ScrollAwareJumpStack extends StatefulWidget {
  const ScrollAwareJumpStack({
    super.key,
    required this.children,
    this.fit = StackFit.loose,
  });
  final List<Widget> children;
  final StackFit fit;

  @override
  State<ScrollAwareJumpStack> createState() => _ScrollAwareJumpStackState();
}

class _ScrollAwareJumpStackState extends State<ScrollAwareJumpStack> {
  final _visible = ValueNotifier(false);
  Timer? _hideTimer;
  bool _userScroll = false;

  bool _onScroll(ScrollNotification event) {
    if (event.metrics.axis != Axis.vertical) return false;
    if (event is ScrollStartNotification && event.dragDetails != null) {
      _userScroll = true;
    }
    if (event is ScrollUpdateNotification && event.dragDetails != null) {
      _userScroll = true;
    }
    if (_userScroll) {
      _visible.value = true;
      _hideTimer?.cancel();
      _hideTimer = Timer(
        const Duration(seconds: 5),
        () => _visible.value = false,
      );
    }
    if (event is ScrollEndNotification) _userScroll = false;
    return false;
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _visible.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: _JumpVisibility(
          notifier: _visible,
          child: Stack(fit: widget.fit, children: widget.children),
        ),
      );
}

class _JumpVisibility extends InheritedNotifier<ValueNotifier<bool>> {
  const _JumpVisibility({required super.notifier, required super.child});
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
