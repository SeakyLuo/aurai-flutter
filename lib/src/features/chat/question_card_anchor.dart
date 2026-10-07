import 'package:flutter/material.dart';

class QuestionCardAnchor extends StatefulWidget {
  const QuestionCardAnchor({
    super.key,
    required this.messageId,
    required this.child,
  });
  final String messageId;
  final Widget child;
  static final _anchors = <String, BuildContext>{};
  static Rect? bounds(String id) {
    final context = _anchors[id];
    if (context == null || !context.mounted) return null;
    final box = context.findRenderObject() as RenderBox;
    if (!box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  State<QuestionCardAnchor> createState() => _QuestionCardAnchorState();
}

class _QuestionCardAnchorState extends State<QuestionCardAnchor> {
  @override
  Widget build(BuildContext context) {
    QuestionCardAnchor._anchors[widget.messageId] = context;
    return widget.child;
  }

  @override
  void dispose() {
    if (identical(QuestionCardAnchor._anchors[widget.messageId], context)) {
      QuestionCardAnchor._anchors.remove(widget.messageId);
    }
    super.dispose();
  }
}

/// Counteracts the sheet's downward exit and returns it to its message bounds.
class QuestionReturnTransition extends StatefulWidget {
  const QuestionReturnTransition({
    super.key,
    required this.target,
    required this.child,
  });
  final Rect? Function() target;
  final Widget child;
  @override
  State<QuestionReturnTransition> createState() =>
      _QuestionReturnTransitionState();
}

class _QuestionReturnTransitionState extends State<QuestionReturnTransition> {
  Animation<double>? _animation;
  Rect? _origin, _target;
  double _start = 1;
  final _layoutKey = GlobalKey();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animation?.removeStatusListener(_status);
    _animation = ModalRoute.of(context)!.animation!;
    _animation!.addStatusListener(_status);
  }

  void _status(AnimationStatus status) {
    if (status != AnimationStatus.reverse ||
        MediaQuery.disableAnimationsOf(context))
      return;
    final box = _layoutKey.currentContext!.findRenderObject()! as RenderBox;
    _origin = box.localToGlobal(Offset.zero) & box.size;
    _target = widget.target();
    _start = _animation!.value;
  }

  @override
  void dispose() {
    _animation?.removeStatusListener(_status);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    key: _layoutKey,
    child: AnimatedBuilder(
      animation: _animation!,
      child: widget.child,
      builder: (context, child) {
        if (_origin == null || _target == null || _start == 0) return child!;
        final progress = ((_start - _animation!.value) / _start).clamp(
          0.0,
          1.0,
        );
        final rect = Rect.lerp(
          _origin,
          _target,
          Curves.easeInOutCubic.transform(progress),
        )!;
        final sliding = Offset(
          0,
          _origin!.height * (_start - _animation!.value),
        );
        return Opacity(
          opacity: 1 - progress,
          child: Transform(
            alignment: Alignment.topLeft,
            transform: Matrix4.identity()
              ..translateByDouble(
                rect.left - _origin!.left - sliding.dx,
                rect.top - _origin!.top - sliding.dy,
                0,
                1,
              )
              ..scaleByDouble(
                rect.width / _origin!.width,
                rect.height / _origin!.height,
                1,
                1,
              ),
            child: child,
          ),
        );
      },
    ),
  );
}
