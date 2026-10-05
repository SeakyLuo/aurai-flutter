import 'package:flutter/material.dart';
import 'detail_split_layout.dart';

/// Keeps the address book mounted while browsing a profile and its subpages.
class ContactProfileSplit extends StatefulWidget {
  const ContactProfileSplit({
    super.key,
    required this.child,
    this.onDetailChanged,
  });
  final Widget child;
  final ValueChanged<bool>? onDetailChanged;

  @override
  State<ContactProfileSplit> createState() => ContactProfileSplitState();
}

class ContactProfileSplitState extends State<ContactProfileSplit>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  late final _curve = CurvedAnimation(
    parent: _animation,
    curve: Curves.easeInOutCubic,
  );
  GlobalKey<NavigatorState>? _navigator;
  Widget? _detail;
  bool _open = false;
  PageRoute<void>? _fullscreenRoute;
  NavigatorState? _rootNavigator;
  bool _layoutQueued = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLayoutAfterFrame();
  }

  @override
  void didChangeMetrics() => _syncLayoutAfterFrame();

  void _syncLayoutAfterFrame() {
    if (_layoutQueued) return;
    _layoutQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _layoutQueued = false;
      if (!mounted || !_open) return;
      final view = View.of(context);
      final wide = view.physicalSize.width / view.devicePixelRatio >= 600;
      if (!wide && _fullscreenRoute == null) {
        final root = Navigator.of(context, rootNavigator: true);
        final route = PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (context, _, _) => PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && _open) _navigator!.currentState!.maybePop();
            },
            child: _detail!,
          ),
        );
        // Move the keyed Navigator itself, preserving its routes and page state.
        setState(() {
          _fullscreenRoute = route;
          _rootNavigator = root;
        });
        root.push(route);
      } else if (wide && _fullscreenRoute != null) {
        _returnToSplit();
      }
    });
  }

  void _returnToSplit() {
    final route = _fullscreenRoute;
    if (route == null) return;
    setState(() => _fullscreenRoute = null);
    _rootNavigator!.removeRoute(route);
    _rootNavigator = null;
  }

  bool get supportsSplit => context.size!.width >= 600;

  Future<T?> open<T>(MaterialPageRoute<T> route) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final navigator = GlobalKey<NavigatorState>();
    setState(() {
      _navigator = navigator;
      _open = true;
      _detail = Navigator(
        key: navigator,
        onGenerateInitialRoutes: (_, _) => [
          MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink()),
          route,
        ],
        onGenerateRoute: (_) => null,
      );
    });
    widget.onDetailChanged?.call(true);
    _animation.forward();
    _syncLayoutAfterFrame();
    final result = await route.popped;
    if (!mounted || _navigator != navigator) return result;
    _returnToSplit();
    setState(() => _open = false);
    await _animation.reverse();
    if (mounted && !_open && _navigator == navigator) {
      setState(() => _detail = null);
      widget.onDetailChanged?.call(false);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_open,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && _open) _navigator!.currentState!.maybePop();
    },
    child: DetailSplitLayout(
      animation: _curve,
      opened: _open && _fullscreenRoute == null,
      detailBuilder: _detail == null || _fullscreenRoute != null
          ? null
          : (_, _) => _detail!,
      child: widget.child,
    ),
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _curve.dispose();
    _animation.dispose();
    super.dispose();
  }
}
