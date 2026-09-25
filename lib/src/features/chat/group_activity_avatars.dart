import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'chat_controller.dart';
import 'member_avatar.dart';
import 'question_icon.dart';

class GroupActivityAvatars extends StatefulWidget {
  const GroupActivityAvatars({
    super.key,
    required this.activities,
    required this.onPressed,
  });

  final List<GroupMemberActivity> activities;
  final VoidCallback onPressed;

  @override
  State<GroupActivityAvatars> createState() => _ActivityAvatarsState();
}

class _ActivityAvatarsState extends State<GroupActivityAvatars>
    with TickerProviderStateMixin {
  static const _showAfter = Duration(seconds: 1);
  static const _avatarSize = 26.0;
  static const _avatarStride = 16.0;
  final _sinceUpdate = Stopwatch()..start();
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );
  late final AnimationController _sleepAnimation =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1848),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _sleepPause = Timer(const Duration(seconds: 4), () {
            _sleepPause = null;
            if (_animate && _visible.any((a) => a.sleeping)) {
              _sleepAnimation.forward(from: 0);
            }
          });
        }
      });
  Timer? _sleepPause;
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
  void didUpdateWidget(GroupActivityAvatars oldWidget) {
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
      if (activity.sleeping ||
          activity.autoReplyPaused ||
          remaining <= Duration.zero) {
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
    if (_animate && _visible.any((a) => !a.sleeping && !a.idle)) {
      if (!_animation.isAnimating) _animation.repeat();
    } else {
      _animation.stop();
      _animation.value = 0;
    }
    if (_animate && _visible.any((a) => a.sleeping)) {
      if (!_sleepAnimation.isAnimating && _sleepPause == null) {
        _sleepAnimation.forward(from: 0);
      }
    } else {
      _sleepPause?.cancel();
      _sleepPause = null;
      _sleepAnimation.reset();
    }
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    _sinceUpdate.stop();
    _sleepPause?.cancel();
    _sleepAnimation.dispose();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _visible.isEmpty || !_routeVisible
      ? const SizedBox.shrink()
      : Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            // The positioned overlay never changes the viewport's bottom padding.
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                heightFactor: 1,
                child: RepaintBoundary(
                  child: TextFieldTapRegion(
                    child: LayoutBuilder(builder: _buildCluster),
                  ),
                ),
              ),
            ),
          ),
        );

  Widget _buildCluster(BuildContext context, BoxConstraints constraints) {
    final colors = Theme.of(context).colorScheme;
    final countStyle = TextStyle(
      color: colors.onSurfaceVariant,
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );
    // Leave the centered jump-to-bottom button in its original position.
    final budget = math.min(144.0, (constraints.maxWidth - 56) / 2);
    final count = math.min(_visible.length, 5);
    final remaining = _visible.length - count;
    var overflowWidth = 0.0;
    if (remaining > 0) {
      final painter = TextPainter(
        text: TextSpan(text: '+$remaining', style: countStyle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      overflowWidth = math.max(26.0, painter.width + 12);
      painter.dispose();
    }
    final overflowExtension = remaining > 0
        ? (overflowWidth - _avatarSize) / 2
        : 0.0;
    final pileBudget = budget - overflowExtension;
    final stride = count > 1
        ? math.min(_avatarStride, (pileBudget - _avatarSize) / (count - 1))
        : _avatarStride;
    final pileWidth = _avatarSize + (count - 1) * stride;
    final shown = _visible.take(count).toList();
    return Semantics(
      button: true,
      label: '查看 ${_visible.length} 位成员的状态',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          child: SizedBox(
            width: pileWidth + overflowExtension,
            height: 40,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < shown.length; i++)
                  Positioned(
                    key: ValueKey(shown[i].runId),
                    left: i * stride,
                    top: 7,
                    child: _buildAvatar(shown[i], i),
                  ),
                if (remaining > 0)
                  Positioned(
                    left: (count - 1) * stride - overflowExtension,
                    top: 7,
                    child: Container(
                      width: overflowWidth,
                      height: _avatarSize,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(_avatarSize / 2),
                        border: Border.all(color: colors.surface),
                      ),
                      child: Text('+$remaining', style: countStyle),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sleepLetter(int index) {
    final progress = ((_sleepAnimation.value * 1848 - index * 224) / 1400)
        .clamp(0.0, 1.0);
    final wave = _animate ? (1 - math.cos(progress * math.pi * 2)) / 2 : 0.0;
    return Transform.scale(
      alignment: Alignment.bottomCenter,
      scale: 1 - .35 * wave,
      child: Text(
        'z',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _framedAvatar(GroupMemberActivity activity) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      shape: BoxShape.circle,
    ),
    child: Padding(
      padding: const EdgeInsets.all(1),
      child: MemberAvatar(sender: activity.sender, size: 24),
    ),
  );

  Widget _buildAvatar(GroupMemberActivity activity, int index) => Stack(
    clipBehavior: Clip.none,
    children: [
      _avatarBody(activity, index),
      if (activity.autoReplyPaused)
        Positioned(
          right: -4,
          top: -6,
          child: Semantics(
            label: '自动接话已暂停',
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(5),
              ),
              child: const SizedBox.square(
                dimension: 16,
                child: QuestionIcon(type: QuestionIconType.pause),
              ),
            ),
          ),
        ),
    ],
  );

  Widget _avatarBody(GroupMemberActivity activity, int index) =>
      activity.sleeping
      ? Stack(
          clipBehavior: Clip.none,
          children: [
            _framedAvatar(activity),
            if (!activity.autoReplyPaused)
              Positioned(
                right: -4,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: AnimatedBuilder(
                    animation: _sleepAnimation,
                    builder: (context, _) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < 3; i++)
                          Padding(
                            padding: EdgeInsets.only(right: i < 2 ? 1.5 : 0),
                            child: _sleepLetter(i),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        )
      : activity.idle
      ? _framedAvatar(activity)
      : AnimatedBuilder(
          animation: _animation,
          child: _framedAvatar(activity),
          builder: (context, child) {
            final phase =
                (_animation.value - index * .19 - (index % 3) * .035) % 1;
            final pose = _animate ? _bouncePose(phase, index) : _restingPose;
            return Transform.translate(
              offset: Offset(0, pose.y),
              child: Transform.rotate(
                angle: pose.angle,
                alignment: Alignment.bottomCenter,
                child: Transform.scale(
                  scaleX: pose.scaleX,
                  scaleY: pose.scaleY,
                  alignment: Alignment.bottomCenter,
                  child: child,
                ),
              ),
            );
          },
        );
}

typedef _BouncePose = ({double y, double scaleX, double scaleY, double angle});

const _BouncePose _restingPose = (y: 0, scaleX: 1, scaleY: 1, angle: 0);

_BouncePose _bouncePose(double phase, int index) {
  final height = 4.5 + (index % 3) * .75;
  final direction = index.isEven ? 1.0 : -1.0;
  if (phase < .08) {
    final press = math.sin(phase / .08 * math.pi);
    return (
      y: .6 * press,
      scaleX: 1 + .08 * press,
      scaleY: 1 - .1 * press,
      angle: 0,
    );
  }
  if (phase < .19) {
    final t = (phase - .08) / .11;
    final stretch = math.sin(t * math.pi);
    return (
      y: -height * Curves.easeOutCubic.transform(t),
      scaleX: 1 - .035 * stretch,
      scaleY: 1 + .065 * stretch,
      angle: direction * .065 * math.sin(t * math.pi / 2),
    );
  }
  if (phase < .33) {
    final t = (phase - .19) / .14;
    return (
      y: -height * (1 - t * t),
      scaleX: 1,
      scaleY: 1,
      angle: direction * .065 * (1 - t),
    );
  }
  if (phase < .40) {
    final press = math.sin((phase - .33) / .07 * math.pi);
    return (
      y: .5 * press,
      scaleX: 1 + .12 * press,
      scaleY: 1 - .1 * press,
      angle: 0,
    );
  }
  if (phase < .50) {
    final rebound = math.sin((phase - .40) / .10 * math.pi);
    return (
      y: -height * .25 * rebound,
      scaleX: 1,
      scaleY: 1,
      angle: -direction * .025 * rebound,
    );
  }
  if (phase < .55) {
    final settle = math.sin((phase - .50) / .05 * math.pi);
    return (
      y: 0,
      scaleX: 1 + .025 * settle,
      scaleY: 1 - .025 * settle,
      angle: 0,
    );
  }
  return _restingPose;
}
