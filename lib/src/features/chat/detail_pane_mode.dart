import 'package:flutter/widgets.dart';

/// Resize the same detail route so its miniapp session stays mounted.
class DetailPaneMode extends InheritedWidget {
  const DetailPaneMode({
    super.key,
    required this.fullscreen,
    required this.onToggle,
    required super.child,
  });
  final bool fullscreen;
  final VoidCallback? onToggle;
  static DetailPaneMode? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DetailPaneMode>();
  @override
  bool updateShouldNotify(DetailPaneMode oldWidget) =>
      fullscreen != oldWidget.fullscreen || onToggle != oldWidget.onToggle;
}
