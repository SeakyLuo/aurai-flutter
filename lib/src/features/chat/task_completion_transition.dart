import 'package:flutter/material.dart';

import 'settings_icon.dart';

/// Finishes at the task icon before removing the banner's reserved space.
class TaskCompletionTransition extends StatefulWidget {
  const TaskCompletionTransition({
    super.key,
    required this.completed,
    required this.child,
  });

  final bool completed;
  final Widget child;

  @override
  State<TaskCompletionTransition> createState() =>
      _TaskCompletionTransitionState();
}

class _TaskCompletionTransitionState extends State<TaskCompletionTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
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
      final check = const Interval(
        0,
        .35,
        curve: Curves.easeOutBack,
      ).transform(_controller.value);
      final exit = const Interval(
        .5,
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
                        left: 30,
                        top: 10,
                        child: Transform.scale(
                          scale: check,
                          child: Container(
                            width: 34,
                            height: 34,
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
