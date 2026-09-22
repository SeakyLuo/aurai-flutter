import 'miniapp_recent_store.dart';
import 'miniapp_favorite_action.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../app/glass_notice.dart';
import '../domain/error_message.dart';
import 'html_game.dart';
import 'html_game_session.dart';
import 'html_game_store.dart';
import 'html_game_surface.dart';
import 'html_route_observer.dart';

/// A library application has no synthetic conversation or message row.
class MiniappRunPage extends StatefulWidget {
  const MiniappRunPage({super.key, required this.game, required this.store});
  final HtmlGame game;
  final HtmlGameStore store;

  @override
  State<MiniappRunPage> createState() => _MiniappRunPageState();
}

class _MiniappRunPageState extends State<MiniappRunPage>
    with WidgetsBindingObserver {
  HtmlGameSession? _session;
  Future<void>? _closing;
  String? _lastError;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    htmlRouteObserver.addListener(_visibility);
    unawaited(_recordOpen());
  }

  Future<void> _recordOpen() async {
    try {
      await recordMiniappOpen(widget.store.database, widget.game.appId);
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showGlassSnackBar(SnackBar(content: Text(errorMessage(error))));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_session == null) {
      _session = HtmlGameSession(
        widget.game,
        widget.store,
        theme: Theme.of(context),
        fullscreen: true,
        independent: true,
        hostTopInset: MediaQuery.paddingOf(context).top + 76,
        hostSafeTopInset: MediaQuery.paddingOf(context).top,
        hostRightInset: 124,
      )..addListener(_changed);
    } else {
      unawaited(_session!.updateTheme(Theme.of(context)));
    }
    _visibility();
  }

  void _changed() {
    if (!mounted || _leaving) return;
    final session = _session!;
    if (session.error != null && session.error != _lastError) {
      _lastError = session.error;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showGlassSnackBar(SnackBar(content: Text(_lastError!)));
      });
    }
    if (session.failed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_leave());
      });
    }
  }

  void _visibility() {
    if (!mounted || _leaving) return;
    final route = ModalRoute.of(context)!;
    final state = WidgetsBinding.instance.lifecycleState;
    final resumed =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    unawaited(
      _session?.setVisible(resumed && htmlRouteObserver.isVisible(route)),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _visibility();

  Future<void> _close() => _closing ??= _session!.close();

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    _session!.removeListener(_changed);
    try {
      await _close();
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showGlassSnackBar(SnackBar(content: Text(errorMessage(error))));
    } finally {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    htmlRouteObserver.removeListener(_visibility);
    _session!.removeListener(_changed);
    if (_closing == null) unawaited(_close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(_leave());
    },
    child: Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          ListenableBuilder(
            listenable: _session!,
            builder: (context, _) => HtmlGameSurface(
              session: _session!,
              borderRadius: BorderRadius.zero,
              loadingBackground: Theme.of(context).scaffoldBackgroundColor,
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top,
            right: 16,
            height: 76,
            child: Center(
              child: MiniappFavoriteAction(
                appId: widget.game.appId,
                onClose: _leave,
                store: widget.store,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
