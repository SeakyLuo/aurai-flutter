import 'package:flutter/material.dart';
import 'detail_split_layout.dart';

/// Keeps the address book mounted while browsing a profile and its subpages.
class ContactProfileSplit extends StatefulWidget {
  const ContactProfileSplit({super.key, required this.child});
  final Widget child;

  @override
  State<ContactProfileSplit> createState() => ContactProfileSplitState();
}

class ContactProfileSplitState extends State<ContactProfileSplit>
    with SingleTickerProviderStateMixin {
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
    _animation.forward();
    final result = await route.popped;
    if (!mounted || _navigator != navigator) return result;
    setState(() => _open = false);
    await _animation.reverse();
    if (mounted && !_open && _navigator == navigator) {
      setState(() => _detail = null);
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
      opened: _open,
      detailBuilder: _detail == null ? null : (_, _) => _detail!,
      child: widget.child,
    ),
  );

  @override
  void dispose() {
    _curve.dispose();
    _animation.dispose();
    super.dispose();
  }
}
