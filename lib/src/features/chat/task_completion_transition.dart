import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'settings_icon.dart';

/// Finishes at the task icon before removing the banner's reserved space.
class TaskCompletionTransition extends StatefulWidget {
  const TaskCompletionTransition({
    super.key,
    required this.completed,
    required this.child,
    required this.iconLink,
    required this.iconSize,
  });

  final bool completed;
  final Widget child;
  final LayerLink iconLink;
  final double iconSize;

  @override
  State<TaskCompletionTransition> createState() =>
      _TaskCompletionTransitionState();
}

class _TaskCompletionTransitionState extends State<TaskCompletionTransition>
    with SingleTickerProviderStateMixin {
  // Match the spring used when swipe-to-quote reaches its ready state.
  static final _checkSpring = SpringSimulation(
    const SpringDescription(mass: 1, stiffness: 340, damping: 14),
    0,
    1,
    9,
  );
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
    value: widget.completed ? 1 : 0,
  );

  @override
  void didUpdateWidget(TaskCompletionTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.completed) {
      _controller.reset();
    } else if (!oldWidget.completed) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) {
      if (_controller.isCompleted) return const SizedBox.shrink();
      final elapsedSeconds = _controller.value * 2;
      final check = _checkSpring.isDone(elapsedSeconds)
          ? 1.0
          : _checkSpring.x(elapsedSeconds);
      final exit = const Interval(
        .8,
        1,
        curve: Curves.easeInOutCubic,
      ).transform(_controller.value);
      return IgnorePointer(
        ignoring: widget.completed,
        child: ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: 1 - exit,
            child: Opacity(
              opacity: 1 - exit,
              child: Transform.translate(
                offset: Offset(0, -24 * exit),
                child: Stack(
                  children: [
                    child!,
                    if (widget.completed)
                      Positioned(
                        left: 0,
                        top: 0,
                        child: CompositedTransformFollower(
                          link: widget.iconLink,
                          showWhenUnlinked: false,
                          targetAnchor: Alignment.center,
                          followerAnchor: Alignment.center,
                          child: Transform.scale(
                            scale: check,
                            child: Container(
                              width: widget.iconSize,
                              height: widget.iconSize,
                              decoration: const BoxDecoration(
                                color: Color(0xff34a66f),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: const SettingsIcon(
                                type: SettingsIconType.check,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
