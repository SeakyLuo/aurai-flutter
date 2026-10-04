import 'package:flutter/material.dart';

/// Gives dialogs and sheets the bounds of their pane instead of the full page.
class PaneNavigator extends StatefulWidget {
  const PaneNavigator({super.key, required this.child, this.handleBack = true});
  final Widget child;
  final bool handleBack;

  @override
  State<PaneNavigator> createState() => PaneNavigatorState();
}

class PaneNavigatorState extends State<PaneNavigator> {
  final _navigator = GlobalKey<NavigatorState>();
  bool get hasOverlayRoute => _navigator.currentState!.canPop();
  @override
  Widget build(BuildContext context) => _PaneContent(
    content: widget.child,
    child: NavigatorPopHandler<Object?>(
      enabled: widget.handleBack,
      onPopWithResult: (_) => _navigator.currentState!.maybePop(),
      child: Navigator(
        key: _navigator,
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (context) => context
              .dependOnInheritedWidgetOfExactType<_PaneContent>()!
              .content,
        ),
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
