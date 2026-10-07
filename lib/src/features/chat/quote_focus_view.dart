import 'dart:ui';
import 'package:flutter/material.dart';
import '../../domain/message_quote.dart';
import 'message_quote_view.dart';
import 'message_time.dart';

/// Keeps the timeline mounted and its scroll position intact while replying.
class QuoteFocusBackground extends StatelessWidget {
  const QuoteFocusBackground({
    super.key,
    required this.active,
    required this.onCancel,
    required this.child,
  });

  final bool active;
  final VoidCallback onCancel;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ImageFiltered(
        enabled: active,
        imageFilter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
        child: IgnorePointer(ignoring: active, child: child),
      ),
      if (active)
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onCancel,
            child: ColoredBox(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: .25),
            ),
          ),
        ),
    ],
  );
}

class QuoteFocusVisual {
  const QuoteFocusVisual({
    required this.rect,
    required this.createdAt,
    required this.sourceRect,
    required this.builder,
  });
  final Rect rect;
  final DateTime createdAt;
  final Rect Function() sourceRect;
  final Widget Function(double maxHeight) builder;
}

class QuoteFocusMessage extends StatefulWidget {
  const QuoteFocusMessage({
    super.key,
    required this.quote,
    required this.onCancel,
    required this.composerKey,
    required this.topInset,
    this.visual,
  });

  final MessageQuote quote;
  final QuoteFocusVisual? visual;
  final VoidCallback onCancel;
  final GlobalKey composerKey;
  final double topInset;

  @override
  State<QuoteFocusMessage> createState() => QuoteFocusMessageState();
}

class QuoteFocusMessageState extends State<QuoteFocusMessage>
    with SingleTickerProviderStateMixin {
  final _targetKey = GlobalKey();
  late final _flight = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  bool _positioned = false;
  bool _returning = false;
  double _composerHeight = 0;

  Future<void> returnToSource() async {
    if (widget.visual == null || MediaQuery.disableAnimationsOf(context))
      return;
    _returning = true;
    await _flight.reverse().orCancel;
  }

  void _measureComposer() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final composer =
          widget.composerKey.currentContext!.findRenderObject()! as RenderBox;
      if (_composerHeight != composer.size.height) {
        setState(() => _composerHeight = composer.size.height);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _startFlight();
  }

  @override
  void didUpdateWidget(QuoteFocusMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visual != widget.visual) _startFlight();
  }

  void _startFlight() {
    _returning = false;
    _positioned = false;
    _flight.value = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.visual == null) return;
      setState(() {
        _positioned = true;
      });
      if (MediaQuery.disableAnimationsOf(context)) {
        _flight.value = 1;
      } else {
        _flight.forward();
      }
    });
  }

  @override
  void dispose() {
    _flight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visual = widget.visual;
    if (visual == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: MessageQuoteView(quote: widget.quote, onClose: widget.onCancel),
      );
    }
    final media = MediaQuery.of(context);
    _measureComposer();
    final available =
        media.size.height -
        media.viewInsets.bottom -
        widget.topInset -
        _composerHeight -
        24 -
        MediaQuery.textScalerOf(context).scale(12) * 1.4 -
        8;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        heightFactor: 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _flight,
              child: Text(
                messageTime(visual.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              key: _targetKey,
              width: visual.rect.width,
              child: AnimatedBuilder(
                animation: _flight,
                child: visual.builder(
                  available.clamp(24.0, visual.rect.height),
                ),
                builder: (context, child) {
                  if (!_positioned) return Opacity(opacity: 0, child: child);
                  final target =
                      _targetKey.currentContext!.findRenderObject()!
                          as RenderBox;
                  final from =
                      (_returning
                          ? visual.sourceRect().topLeft
                          : visual.rect.topLeft) -
                      target.localToGlobal(Offset.zero);
                  return Transform.translate(
                    offset:
                        from *
                        (1 - Curves.easeOutCubic.transform(_flight.value)),
                    child: child,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
