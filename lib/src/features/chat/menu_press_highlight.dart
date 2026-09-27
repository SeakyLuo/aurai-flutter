import 'package:flutter/material.dart';

class MenuPressHighlight extends StatefulWidget {
  const MenuPressHighlight({
    super.key,
    required this.onLongPressStart,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.customBorder,
  });

  final Future<void> Function(LongPressStartDetails)? onLongPressStart;
  final Widget child;
  final BorderRadius borderRadius;
  final ShapeBorder? customBorder;

  static VoidCallback? _dismissActive;

  static void dismissActive() => _dismissActive?.call();

  @override
  State<MenuPressHighlight> createState() => _MenuPressHighlightState();
}

class _MenuPressHighlightState extends State<MenuPressHighlight> {
  late final VoidCallback _dismissCallback = _dismiss;
  bool _pressed = false;
  bool _opening = false;

  void _dismiss() {
    if (!_opening && !_pressed) return;
    if (identical(MenuPressHighlight._dismissActive, _dismissCallback)) {
      MenuPressHighlight._dismissActive = null;
    }
    if (mounted) {
      setState(() {
        _opening = false;
        _pressed = false;
      });
    } else {
      _opening = false;
      _pressed = false;
    }
  }

  void _press() {
    if (!_pressed) setState(() => _pressed = true);
  }

  void _release() {
    if (_pressed && !_opening) setState(() => _pressed = false);
  }

  Future<void> _open(LongPressStartDetails details) async {
    if (_opening) return;
    final onLongPressStart = widget.onLongPressStart;
    if (onLongPressStart == null) return;
    MenuPressHighlight.dismissActive();
    setState(() {
      _opening = true;
      _pressed = true;
    });
    MenuPressHighlight._dismissActive = _dismissCallback;
    try {
      await onLongPressStart(details);
    } finally {
      _dismiss();
    }
  }

  @override
  void dispose() {
    if (identical(MenuPressHighlight._dismissActive, _dismissCallback)) {
      MenuPressHighlight._dismissActive = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onLongPressStart == null) return widget.child;
    final theme = Theme.of(context);
    return GestureDetector(
      onTapDown: (_) => _press(),
      onTapUp: (_) => _release(),
      onTapCancel: _release,
      onLongPressStart: _open,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Theme(
            data: theme.copyWith(highlightColor: Colors.transparent),
            child: widget.child,
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: AnimatedOpacity(
                  opacity: _pressed || _opening ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.linear,
                  child: Material(
                    color: theme.highlightColor,
                    borderRadius: widget.customBorder == null
                        ? widget.borderRadius
                        : null,
                    shape: widget.customBorder,
                    clipBehavior: Clip.antiAlias,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
