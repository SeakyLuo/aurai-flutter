import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'chat_controller.dart';
import 'member_avatar.dart';

class GroupActivityComposer extends StatelessWidget {
  const GroupActivityComposer({
    super.key,
    required this.conversationId,
    required this.activities,
    required this.child,
  });

  final String? conversationId;
  final List<GroupMemberActivity> activities;
  final Widget child;

  @override
  Widget build(BuildContext context) => conversationId == null
      ? child
      : Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActivityAvatars(
              key: ValueKey(conversationId),
              activities: activities,
            ),
            child,
          ],
        );
}

class _ActivityAvatars extends StatefulWidget {
  const _ActivityAvatars({super.key, required this.activities});

  final List<GroupMemberActivity> activities;

  @override
  State<_ActivityAvatars> createState() => _ActivityAvatarsState();
}

class _ActivityAvatarsState extends State<_ActivityAvatars>
    with SingleTickerProviderStateMixin {
  static const _showAfter = Duration(seconds: 1);
  final _sinceUpdate = Stopwatch()..start();
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  Timer? _revealTimer;
  List<GroupMemberActivity> _visible = const [];
  bool _animate = false;
  bool _routeVisible = true;

  @override
  void initState() {
    super.initState();
    _updateVisible();
  }

  @override
  void didUpdateWidget(_ActivityAvatars oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sinceUpdate.reset();
    _updateVisible();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeVisible = ModalRoute.isCurrentOf(context) != false;
    _animate =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled &&
        _routeVisible;
    _updateAnimation();
  }

  void _updateVisible() {
    _revealTimer?.cancel();
    final visible = <GroupMemberActivity>[];
    Duration? nextReveal;
    for (final activity in widget.activities) {
      final remaining = _showAfter - activity.elapsed - _sinceUpdate.elapsed;
      if (remaining <= Duration.zero) {
        visible.add(activity);
      } else if (nextReveal == null || remaining < nextReveal) {
        nextReveal = remaining;
      }
    }
    _visible = visible;
    if (nextReveal != null) {
      _revealTimer = Timer(nextReveal, () => setState(_updateVisible));
    }
    _updateAnimation();
  }

  void _updateAnimation() {
    if (_animate && _visible.isNotEmpty) {
      if (!_animation.isAnimating) _animation.repeat();
    } else {
      _animation.stop();
      _animation.value = 0;
    }
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    _sinceUpdate.stop();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      // Keep the viewport's bottom padding stable when activity changes.
      child: SizedBox(
        height: 40,
        width: double.infinity,
        child: _visible.isEmpty || !_routeVisible
            ? null
            : RepaintBoundary(
                child: TextFieldTapRegion(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        for (var i = 0; i < _visible.length; i++)
                          _buildAvatar(_visible[i], i),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    ),
  );

  Widget _buildAvatar(GroupMemberActivity activity, int index) => Tooltip(
    key: ValueKey(activity.runId),
    message: '${activity.sender.name} · ${activity.description}',
    triggerMode: TooltipTriggerMode.tap,
    preferBelow: false,
    showDuration: const Duration(seconds: 2),
    child: SizedBox.square(
      dimension: 40,
      child: Center(
        child: AnimatedBuilder(
          animation: _animation,
          child: MemberAvatar(sender: activity.sender, size: 28),
          builder: (context, child) {
            final phase = (_animation.value - index * 0.14) % 1;
            final lift = _animate && phase < 0.5
                ? math.sin(phase * math.pi * 2) * 2
                : 0.0;
            return Transform.translate(offset: Offset(0, -lift), child: child);
          },
        ),
      ),
    ),
  );
}
