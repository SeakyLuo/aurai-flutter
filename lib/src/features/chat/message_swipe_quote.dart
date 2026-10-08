import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/gestures.dart';

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
    with TickerProviderStateMixin {
  double _threshold = 64;
  static const _maximum = 88.0;
  static const _returnSpring = SpringDescription(
    mass: 1,
    stiffness: 360,
    damping: 22,
  );
  static const _feedbackSpring = SpringDescription(
    mass: 1,
    stiffness: 340,
    damping: 14,
  );
  late final _offset = AnimationController.unbounded(vsync: this);
  late final _feedback = AnimationController.unbounded(vsync: this);
  double _distance = 0;
  bool _hapticSent = false;
  final _stackKey = GlobalKey();
  Rect _bubbleBounds = Rect.zero;

  @override
  void dispose() {
    _offset.dispose();
    _feedback.dispose();
    super.dispose();
  }

  void _reset() {
    _distance = 0;
    if (MediaQuery.disableAnimationsOf(context)) {
      _offset.value = 0;
      _feedback.value = 0;
    } else {
      _offset.animateWith(SpringSimulation(_returnSpring, _offset.value, 0, 0));
      _feedback.animateWith(
        SpringSimulation(_feedbackSpring, _feedback.value, 0, 0),
      );
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    dragStartBehavior: DragStartBehavior.down,
    onHorizontalDragStart: (_) {
      _offset.stop();
      _feedback.stop();
      final stack = _stackKey.currentContext!.findRenderObject()! as RenderBox;
      final bubble =
          widget.anchorKey.currentContext!.findRenderObject()! as RenderBox;
      _bubbleBounds =
          (bubble.localToGlobal(Offset.zero, ancestor: stack) -
              Offset(_offset.value, 0)) &
          bubble.size;
      _threshold = (bubble.size.width / 2).clamp(32.0, 64.0);
      _distance = _offset.value.clamp(0, _maximum);
      _feedback.value = _distance >= _threshold ? 1 : 0;
      _hapticSent = false;
    },
    onHorizontalDragUpdate: (details) {
      final wasReady = _distance >= _threshold;
      _distance = (_distance + details.delta.dx).clamp(0.0, _maximum);
      _offset.value = _distance;
      if (_distance < _threshold) {
        if (wasReady) {
          if (MediaQuery.disableAnimationsOf(context)) {
            _feedback.value = 0;
          } else {
            _feedback.animateWith(
              SpringSimulation(_returnSpring, _feedback.value, 0, 0),
            );
          }
        }
      } else if (!wasReady) {
        if (MediaQuery.disableAnimationsOf(context)) {
          _feedback.value = 1;
        } else {
          _feedback.animateWith(
            SpringSimulation(_feedbackSpring, _feedback.value, 1, 9),
          );
        }
      }
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
      animation: Listenable.merge([_offset, _feedback]),
      child: widget.child,
      builder: (context, child) {
        final readyProgress = _feedback.value.clamp(0.0, 1.5);
        final indicatorInset = (40 - _threshold).clamp(0.0, 8.0);
        return Stack(
          key: _stackKey,
          alignment: Alignment.centerLeft,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: _bubbleBounds.left - indicatorInset,
              top: _bubbleBounds.center.dy - 20,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: Opacity(
                    opacity: Curves.easeIn.transform(
                      ((_offset.value - 12) / (_threshold - 12)).clamp(
                        0.0,
                        1.0,
                      ),
                    ),
                    child: ClipRect(
                      clipper: _SwipeQuoteReveal(
                        (_offset.value + indicatorInset).clamp(0, 40),
                      ),
                      child: SizedBox.square(
                        dimension: 40,
                        child: Center(
                          child: Transform.scale(
                            scale: 1 + .08 * readyProgress,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).colorScheme.onSurface
                                    .withValues(alpha: .075 * readyProgress),
                              ),
                              child: Center(
                                child: Transform.scale(
                                  scale: 1 + .14 * readyProgress,
                                  child: const QuoteIcon(),
                                ),
                              ),
                            ),
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
        );
      },
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
