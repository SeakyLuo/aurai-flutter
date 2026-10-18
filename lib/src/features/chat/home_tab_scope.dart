import 'package:flutter/widgets.dart';

/// Tab selection is independent of route animations and opaque pages above it.
class HomeTabScope extends InheritedWidget {
  const HomeTabScope({super.key, required this.active, required super.child});

  final bool active;

  static bool isActive(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeTabScope>()?.active ??
      true;

  @override
  bool updateShouldNotify(HomeTabScope oldWidget) => active != oldWidget.active;
}
