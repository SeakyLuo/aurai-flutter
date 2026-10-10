import 'package:flutter/material.dart';
import '../../html_games/html_route_observer.dart';

/// Gives dialogs and sheets the bounds of their pane instead of the full page.
class PaneNavigator extends StatefulWidget {
  const PaneNavigator({
    super.key,
    required this.child,
    this.handleBack = true,
    this.onVisibilityChanged,
  });
  final Widget child;
  final bool handleBack;
  final ValueChanged<bool>? onVisibilityChanged;

  @override
  State<PaneNavigator> createState() => PaneNavigatorState();
}

class PaneNavigatorState extends State<PaneNavigator> {
  final _navigator = GlobalKey<NavigatorState>();
  final _routeObserver = HtmlRouteObserver();
  late final _contentRoute = MaterialPageRoute<void>(
    builder: (context) =>
        context.dependOnInheritedWidgetOfExactType<_PaneContent>()!.content,
  );
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _routeObserver.addListener(_recordVisibility);
  }

  void _recordVisibility() {
    final visible = _routeObserver.isVisible(_contentRoute);
    if (_visible == visible) return;
    _visible = visible;
    widget.onVisibilityChanged?.call(visible);
  }

  @override
  void dispose() {
    _routeObserver.removeListener(_recordVisibility);
    _routeObserver.dispose();
    super.dispose();
  }

  bool get hasOverlayRoute => _navigator.currentState!.canPop();
  @override
  Widget build(BuildContext context) => _PaneContent(
    content: widget.child,
    child: NavigatorPopHandler<Object?>(
      enabled: widget.handleBack,
      onPopWithResult: (_) => _navigator.currentState!.maybePop(),
      child: Navigator(
        key: _navigator,
        observers: [_routeObserver],
        onGenerateRoute: (_) => _contentRoute,
      ),
    ),
  );
}

class _PaneContent extends InheritedWidget {
  const _PaneContent({required this.content, required super.child});
  final Widget content;

  @override
  bool updateShouldNotify(_PaneContent oldWidget) =>
      content != oldWidget.content;
}
