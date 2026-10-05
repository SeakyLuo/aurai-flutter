import 'dart:ui';
import 'package:flutter/material.dart';
import '../../app/global_ui.dart';

/// One compositing boundary per sheet, including custom modal routes.
class AppSheetSurface extends StatelessWidget {
  const AppSheetSurface({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final parent = _SheetSurfaceScope.maybeOf(context);
    if (parent != null && parent.route == route) return child;
    final surface = Theme.of(context).colorScheme.surface;
    return _SheetSurfaceScope(
      route: route,
      child: ClipRRect(
        borderRadius: GlobalUI.bottomSheetBorderRadius,
        clipBehavior: Clip.antiAliasWithSaveLayer,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [surface.withValues(alpha: .94), surface],
                stops: const [0, .18],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _SheetSurfaceScope extends InheritedWidget {
  const _SheetSurfaceScope({required this.route, required super.child});
  final ModalRoute<dynamic>? route;
  static _SheetSurfaceScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SheetSurfaceScope>();
  @override
  bool updateShouldNotify(_SheetSurfaceScope oldWidget) =>
      route != oldWidget.route;
}
