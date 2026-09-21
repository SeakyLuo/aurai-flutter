import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'message_quote_view.dart';
import 'group_message_heading.dart';

class MessageSwipeQuote extends StatefulWidget {
  const MessageSwipeQuote({
    super.key,
    required this.onQuote,
    required this.child,
    this.belowAvatar = false,
  });

  final VoidCallback onQuote;
  final Widget child;
  final bool belowAvatar;

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
        alignment: Alignment.centerLeft,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: widget.belowAvatar
                ? -GroupMessageHeading.avatarGap -
                      GroupMessageHeading.avatarSize +
                      2
                : 16,
            top: widget.belowAvatar ? 28 : null,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: Opacity(
                  opacity: (_offset.value / _threshold).clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(
                      0,
                      widget.belowAvatar
                          ? -8 *
                                (1 -
                                    (_offset.value / _threshold).clamp(
                                      0.0,
                                      1.0,
                                    ))
                          : 0,
                    ),
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.surface,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: QuoteIcon(
                        color: _offset.value >= _threshold
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
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
