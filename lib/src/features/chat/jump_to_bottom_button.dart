import 'dart:math' as math;
import '../../domain/agent_models.dart';

import 'package:flutter/material.dart';

import 'glass_surface.dart';
import 'settings_icon.dart';
import '../../app/global_ui.dart';
import '../../domain/message_sender.dart';

class JumpToBottomButton extends StatelessWidget {
  const JumpToBottomButton({
    super.key,
    required this.streaming,
    required this.onPressed,
    this.visible = true,
    this.alignUnreadToRight = false,
  });

  final bool streaming;
  final bool visible;
  final bool alignUnreadToRight;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final visibility = context
        .dependOnInheritedWidgetOfExactType<_JumpVisibility>()!
        .notifier!;
    return ValueListenableBuilder<({bool visible, int unread})>(
      valueListenable: visibility,
      builder: (context, state, child) {
        final shown = state.unread > 0 || (visible && state.visible);
        final duration = MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220);
        final button = IgnorePointer(
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
                  child: state.unread > 0
                      ? GlassSurface(
                          radius: 24,
                          child: TextButton.icon(
                            onPressed: onPressed,
                            style: TextButton.styleFrom(
                              foregroundColor: GlobalUI.taskTimeColor(context),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                            icon: SizedBox.square(
                              dimension: 18,
                              child: RotatedBox(
                                quarterTurns: 1,
                                child: SettingsIcon(
                                  type: SettingsIconType.chevron,
                                  color: GlobalUI.taskTimeColor(context),
                                ),
                              ),
                            ),
                            label: Text('${state.unread}条新消息'),
                          ),
                        )
                      : child,
                ),
              ),
            ),
          ),
        );
        if (!alignUnreadToRight) return button;
        return Align(
          alignment: state.unread > 0
              ? Alignment.centerRight
              : Alignment.center,
          child: Padding(
            padding: EdgeInsets.only(right: state.unread > 0 ? 16 : 0),
            child: button,
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
    this.messages = const [],
    this.atBottom = false,
  });
  final List<Widget> children;
  final StackFit fit;
  final List<AgentMessage> messages;
  final bool atBottom;

  @override
  State<ScrollAwareJumpStack> createState() => _ScrollAwareJumpStackState();
}

class _ScrollAwareJumpStackState extends State<ScrollAwareJumpStack> {
  final _visible = ValueNotifier((visible: false, unread: 0));
  final _unread = <String>{};
  DateTime? _latest;

  @override
  void initState() {
    super.initState();
    _trackMessages(initial: true);
    _latest ??= DateTime.now();
  }

  void _trackMessages({bool initial = false}) {
    final previous = _latest;
    for (final message in widget.messages) {
      if (message.isReasoning ||
          message.isSystem ||
          message.quickReplyToId != null ||
          message.senderId == MessageSender.localUser.id ||
          message.role != AgentMessageRole.assistant ||
          !(message.interactive?.canView(MessageSender.localUser.id) ?? true)) {
        continue;
      }
      if (!initial &&
          previous != null &&
          message.createdAt.isAfter(previous) &&
          !widget.atBottom) {
        _unread.add(message.id);
      }
      if (_latest == null || message.createdAt.isAfter(_latest!)) {
        _latest = message.createdAt;
      }
    }
    if (widget.atBottom) _unread.clear();
    _visible.value = (
      visible: widget.atBottom ? false : _visible.value.visible,
      unread: _unread.length,
    );
  }

  @override
  void didUpdateWidget(ScrollAwareJumpStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _trackMessages();
  }

  bool _onScroll(ScrollNotification event) {
    if (event.depth != 0 || event.metrics.axis != Axis.vertical) return false;
    if (event is ScrollUpdateNotification && event.dragDetails != null) {
      final delta = event.scrollDelta ?? 0;
      if (delta != 0) {
        final towardEnd = event.metrics.axisDirection == AxisDirection.down
            ? delta > 0
            : delta < 0;
        _visible.value = (
          visible: towardEnd && !widget.atBottom,
          unread: _unread.length,
        );
      }
    }
    return false;
  }

  @override
  void dispose() {
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

class _JumpVisibility
    extends InheritedNotifier<ValueNotifier<({bool visible, int unread})>> {
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
