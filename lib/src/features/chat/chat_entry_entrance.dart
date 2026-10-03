import 'package:flutter/material.dart';

class ChatEntryEntrance extends StatefulWidget {
  const ChatEntryEntrance({
    required this.animate,
    required this.child,
    required this.removing,
    required this.onRemoved,
  });

  final bool animate;
  final Widget child;
  final bool removing;
  final VoidCallback onRemoved;

  @override
  State<ChatEntryEntrance> createState() => _ChatEntryEntranceState();
}

class _ChatEntryEntranceState extends State<ChatEntryEntrance>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 260);
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
    value: widget.animate ? 0 : 1,
  );
  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutCubic,
  );

  @override
  void initState() {
    super.initState();
    if (widget.removing) {
      _remove();
    } else if (widget.animate) {
      _controller.forward();
    }
  }

  void _remove() {
    _controller.reverse().then((_) {
      if (mounted && widget.removing) widget.onRemoved();
    });
  }

  @override
  void didUpdateWidget(ChatEntryEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.removing && !oldWidget.removing) {
      _remove();
    } else if (!widget.removing && oldWidget.removing) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    if (widget.removing) widget.onRemoved();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizeTransition(
    sizeFactor: _animation,
    alignment: Alignment.topCenter,
    child: FadeTransition(opacity: _animation, child: widget.child),
  );
}
