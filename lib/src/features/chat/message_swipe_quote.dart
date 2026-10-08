import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'message_quote_view.dart';

class MessageSwipeQuote extends StatefulWidget {
  const MessageSwipeQuote({
    super.key,
    required this.onQuote,
    required this.child,
    required this.anchorKey,
  });

  final VoidCallback onQuote;
  final Widget child;
  final GlobalKey anchorKey;

  @override
  State<MessageSwipeQuote> createState() => _MessageSwipeQuoteState();
}

class _MessageSwipeQuoteState extends State<MessageSwipeQuote>
    with SingleTickerProviderStateMixin {
  static const _threshold = 64.0;
  static const _maximum = 88.0;
  late final _offset = AnimationController(
    vsync: this,
    upperBound: _maximum,
    duration: const Duration(milliseconds: 180),
  );
  double _distance = 0;
  bool _hapticSent = false;
  final _stackKey = GlobalKey();
  Rect _bubbleBounds = Rect.zero;

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  void _reset() {
    _distance = 0;
    if (MediaQuery.disableAnimationsOf(context)) {
      _offset.value = 0;
    } else {
      _offset.animateTo(0, curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onHorizontalDragStart: (_) {
      _offset.stop();
      final stack = _stackKey.currentContext!.findRenderObject()! as RenderBox;
      final bubble =
          widget.anchorKey.currentContext!.findRenderObject()! as RenderBox;
      _bubbleBounds =
          (bubble.localToGlobal(Offset.zero, ancestor: stack) -
              Offset(_offset.value, 0)) &
          bubble.size;
      _distance = 0;
      _hapticSent = false;
    },
    onHorizontalDragUpdate: (details) {
      _distance = (_distance + details.delta.dx).clamp(0.0, _maximum);
      _offset.value = _distance;
      if (_distance >= _threshold && !_hapticSent) {
        _hapticSent = true;
        HapticFeedback.selectionClick();
      }
    },
    onHorizontalDragEnd: (_) {
      final quote = _distance >= _threshold;
      _reset();
      if (quote) widget.onQuote();
    },
    onHorizontalDragCancel: _reset,
    child: AnimatedBuilder(
      animation: _offset,
      child: widget.child,
      builder: (context, child) => Stack(
        key: _stackKey,
        alignment: Alignment.centerLeft,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: _bubbleBounds.left + 4,
            top: _bubbleBounds.center.dy - 16,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: Opacity(
                  opacity: (_offset.value / _threshold).clamp(0.0, 1.0),
                  child: ClipRect(
                    clipper: _SwipeQuoteReveal(
                      (_offset.value - 12).clamp(0, 32),
                    ),
                    child: AnimatedContainer(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.onSurface
                            .withValues(
                              alpha: _offset.value >= _threshold ? .06 : 0,
                            ),
                      ),
                      child: Center(
                        child: AnimatedScale(
                          scale: _offset.value >= _threshold ? 1.12 : 1,
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 160),
                          curve: Curves.easeOutBack,
                          child: QuoteIcon(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(offset: Offset(_offset.value, 0), child: child),
        ],
      ),
    ),
  );
}

/// Reveal only the space uncovered by the moving bubble. The icon stays put.
class _SwipeQuoteReveal extends CustomClipper<Rect> {
  const _SwipeQuoteReveal(this.width);
  final double width;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, width, size.height);

  @override
  bool shouldReclip(_SwipeQuoteReveal oldClipper) => width != oldClipper.width;
}
