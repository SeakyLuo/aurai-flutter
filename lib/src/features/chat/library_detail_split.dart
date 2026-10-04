import 'dart:async';
import 'package:flutter/material.dart';
import 'detail_split_layout.dart';

class LibraryDetailSplit extends StatefulWidget {
  const LibraryDetailSplit({super.key, required this.child});
  final Widget child;
  @override
  State<LibraryDetailSplit> createState() => LibraryDetailSplitState();
}

class LibraryDetailSplitState extends State<LibraryDetailSplit>
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
  Completer<void>? _result;
  bool _open = false;

  Future<void> open(MaterialPageRoute<void> route) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (context.size!.width < 600) {
      await Navigator.of(context).push<void>(route);
      return;
    }
    _result?.complete();
    final result = Completer<void>();
    final navigator = GlobalKey<NavigatorState>();
    _result = result;
    _navigator = navigator;
    setState(() {
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
    route.popped.then((_) {
      if (!mounted || !identical(_result, result)) return;
      _result = null;
      setState(() => _open = false);
      _animation.reverse().then((_) {
        if (mounted && !_open && _animation.isDismissed) {
          setState(() => _detail = null);
        }
      });
      result.complete();
    });
    _animation.forward();
    await result.future;
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
    _result?.complete();
    _curve.dispose();
    _animation.dispose();
    super.dispose();
  }
}
