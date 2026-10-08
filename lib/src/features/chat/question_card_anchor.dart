import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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

  static bool isVisible(BuildContext context, {String? messageId}) {
    final id =
        messageId ??
        context.findAncestorWidgetOfExactType<QuestionCardAnchor>()?.messageId;
    final anchor = _anchors[id];
    if (anchor == null || !anchor.mounted) return false;
    final box = anchor.findRenderObject() as RenderBox;
    if (!box.hasSize) return false;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final viewport = RenderAbstractViewport.maybeOf(box) as RenderBox?;
    final screen = Offset.zero & MediaQuery.sizeOf(anchor);
    final visibleArea = viewport == null
        ? screen
        : (viewport.localToGlobal(Offset.zero) & viewport.size).intersect(
            screen,
          );
    return rect.overlaps(visibleArea);
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

/// Counteracts the downward exit only when its question is absent from the view.
class QuestionReturnTransition extends StatefulWidget {
  const QuestionReturnTransition({
    super.key,
    required this.hasVisibleQuestion,
    required this.child,
  });
  final bool Function() hasVisibleQuestion;
  final Widget child;
  @override
  State<QuestionReturnTransition> createState() =>
      _QuestionReturnTransitionState();
}

class _QuestionReturnTransitionState extends State<QuestionReturnTransition> {
  Animation<double>? _animation;
  Rect? _origin;
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
    if (status == AnimationStatus.forward) {
      _origin = null;
      return;
    }
    if (status != AnimationStatus.reverse ||
        MediaQuery.disableAnimationsOf(context))
      return;
    if (widget.hasVisibleQuestion()) {
      _origin = null;
      return;
    }
    final box = _layoutKey.currentContext!.findRenderObject()! as RenderBox;
    _origin = box.localToGlobal(Offset.zero) & box.size;
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
        if (_origin == null || _start == 0) return child!;
        final progress = ((_start - _animation!.value) / _start).clamp(
          0.0,
          1.0,
        );
        final eased = Curves.easeInOutCubic.transform(progress);
        final sliding = Offset(
          0,
          _origin!.height * (_start - _animation!.value),
        );
        return Opacity(
          opacity: 1 - progress,
          child: Transform(
            alignment: Alignment.topLeft,
            transform: Matrix4.identity()
              ..translateByDouble(-sliding.dx, -64 * eased - sliding.dy, 0, 1)
              ..scaleByDouble(1 - .06 * eased, 1 - .06 * eased, 1, 1),
            child: child,
          ),
        );
      },
    ),
  );
}
