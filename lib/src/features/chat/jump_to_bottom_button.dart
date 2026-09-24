import '../../domain/agent_models.dart';
import 'package:flutter/material.dart';
import 'glass_surface.dart';
import 'message_jump_arrow.dart';
import '../../app/global_ui.dart';
import '../../domain/message_sender.dart';

class JumpToBottomButton extends StatelessWidget {
  const JumpToBottomButton({
    super.key,
    required this.onPressed,
    this.visible = true,
    this.newMessagesOnly = false,
  });

  final bool visible;
  final bool newMessagesOnly;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final visibility = context
        .dependOnInheritedWidgetOfExactType<_JumpVisibility>()!
        .notifier!;
    return ValueListenableBuilder<({bool visible, int unread})>(
      valueListenable: visibility,
      builder: (context, state, _) {
        final shown =
            state.unread > 0 || (!newMessagesOnly && visible && state.visible);
        final duration = MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220);
        final color = GlobalUI.taskTimeColor(context);
        return IgnorePointer(
          ignoring: !shown,
          child: ExcludeSemantics(
            excluding: !shown,
            child: AnimatedOpacity(
              opacity: shown ? 1 : 0,
              duration: duration,
              child: AnimatedSlide(
                offset: shown ? Offset.zero : const Offset(0, .2),
                duration: duration,
                curve: Curves.easeOutCubic,
                child: GlassSurface(
                  radius: 24,
                  child: AnimatedSize(
                    duration: duration,
                    alignment: Alignment.centerRight,
                    curve: Curves.easeOutCubic,
                    child: TextButton(
                      onPressed: onPressed,
                      style: TextButton.styleFrom(
                        foregroundColor: color,
                        minimumSize: const Size(56, 40),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: const StadiumBorder(),
                      ),
                      child: Semantics(
                        label: state.unread > 0
                            ? '${state.unread}条新消息，回到最新消息'
                            : '回到底部',
                        excludeSemantics: true,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            MessageJumpArrow(color: color),
                            if (state.unread > 0) ...[
                              const SizedBox(width: 6),
                              Text(
                                '${state.unread > 9999 ? '9999+' : state.unread}条新消息',
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
    this.acknowledgedRunId,
  });
  final List<Widget> children;
  final StackFit fit;
  final List<AgentMessage> messages;
  final bool atBottom;
  final String? acknowledgedRunId;

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
      final acknowledged =
          widget.acknowledgedRunId != null &&
          message.runId == widget.acknowledgedRunId;
      if (acknowledged) _unread.remove(message.id);
      if (!initial &&
          previous != null &&
          message.createdAt.isAfter(previous) &&
          !widget.atBottom &&
          !acknowledged) {
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
