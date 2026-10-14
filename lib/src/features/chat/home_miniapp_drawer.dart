import 'package:flutter/material.dart';

import '../../html_games/miniapp_home_panel.dart';
import 'chat_controller.dart';
import 'glass_surface.dart';
import 'settings_icon.dart';

/// Pulling beyond the start of the chat list reveals the launcher behind it.
class HomeMiniappDrawer extends StatefulWidget {
  const HomeMiniappDrawer({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onChanged,
    required this.child,
  });

  final ChatController controller;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final Widget child;

  @override
  State<HomeMiniappDrawer> createState() => HomeMiniappDrawerState();
}

class HomeMiniappDrawerState extends State<HomeMiniappDrawer>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  final _panel = GlobalKey<MiniappHomePanelState>();
  bool _active = false, _created = false, _pulling = false;
  double _pull = 0, _height = 1;

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(HomeMiniappDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _active) close();
  }

  void _activate() {
    if (_active) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _panel.currentState?.reload();
    setState(() {
      _active = true;
      _created = true;
    });
    widget.onChanged(true);
  }

  Future<void> _settle(bool open) async {
    _pulling = false;
    _pull = 0;
    await _animation.animateTo(
      open ? 1 : 0,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
    if (!mounted || open || _animation.value != 0) return;
    setState(() => _active = false);
    widget.onChanged(false);
  }

  void close() => _settle(false);

  bool _onScroll(ScrollNotification event) {
    if (!widget.enabled ||
        event.metrics.axis != Axis.vertical ||
        _animation.isAnimating ||
        _animation.value == 1) {
      return false;
    }
    if (event is ScrollStartNotification && event.dragDetails != null) {
      _pulling = event.metrics.extentBefore == 0;
      _pull = 0;
    } else if (_pulling && event is OverscrollNotification) {
      if (event.dragDetails != null && event.overscroll < 0) {
        _activate();
        _pull -= event.overscroll;
        _animation.value = (_pull / _height).clamp(0, .9);
      }
    } else if (_pulling && event is ScrollUpdateNotification) {
      final delta = event.dragDetails?.delta.dy ?? 0;
      if (_pull > 0 && delta < 0) {
        _pull = (_pull + delta).clamp(0, _height);
        _animation.value = (_pull / _height).clamp(0, .9);
      }
    } else if (_pulling && event is ScrollEndNotification) {
      if (_active) _settle(_pull >= 80);
      _pulling = false;
    }
    return false;
  }

  void _closeDrag(DragUpdateDetails details) {
    _animation.value = (_animation.value + details.delta.dy / _height).clamp(
      0,
      1,
    );
  }

  void _closeEnd(DragEndDetails details) {
    _settle(details.primaryVelocity! >= -300 && _animation.value > .85);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _height = constraints.maxHeight;
      return ClipRect(
        child: AnimatedBuilder(
          animation: _animation,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                physics: const ClampingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
              ),
              child: widget.child,
            ),
          ),
          builder: (context, child) => Stack(
            fit: StackFit.expand,
            children: [
              if (_created)
                Offstage(
                  offstage: !_active,
                  child: MiniappHomePanel(
                    key: _panel,
                    controller: widget.controller,
                    onClose: close,
                  ),
                ),
              Transform.translate(
                key: const ValueKey('home-chat-page'),
                offset: Offset(0, _animation.value * _height),
                child: IgnorePointer(
                  ignoring: _animation.value == 1,
                  child: ExcludeSemantics(
                    excluding: _active,
                    child: ClipRRect(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(32 * _animation.value),
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),
              if (_active)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: -100 * (1 - _animation.value),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: _closeDrag,
                    onVerticalDragEnd: _closeEnd,
                    onVerticalDragCancel: () => _settle(true),
                    child: _ChatReturnLip(onPressed: close),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _ChatReturnLip extends StatelessWidget {
  const _ChatReturnLip({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => GlassSurface(
    regular: true,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onPressed,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: .2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '聊天',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    RotatedBox(
                      quarterTurns: 2,
                      child: const SettingsIcon(
                        type: SettingsIconType.chevronDown,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
