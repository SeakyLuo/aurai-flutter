import 'package:flutter/material.dart';

final htmlRouteObserver = HtmlRouteObserver();

/// Popup menus leave the underlying page and its live HTML visible.
class HtmlRouteObserver extends NavigatorObserver with ChangeNotifier {
  final _routes = <Route<dynamic>>[];

  bool isVisible(Route<dynamic> route) {
    for (final entry in _routes.reversed) {
      if (identical(entry, route)) return true;
      if (entry is PageRoute) return false;
    }
    return route.isCurrent;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    notifyListeners();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    notifyListeners();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    notifyListeners();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = _routes.indexOf(oldRoute!);
    if (newRoute == null) {
      _routes.removeAt(index);
    } else {
      _routes[index] = newRoute;
    }
    notifyListeners();
  }
}
