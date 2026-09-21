import 'miniapp_favorite_action.dart';
import '../app/glass_notice.dart';
import 'html_game_display_cache.dart';
import '../domain/error_message.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../features/chat/settings_appearance.dart';
import '../features/chat/settings_icon.dart';
import 'html_game.dart';
import 'html_game_session.dart';
import 'html_game_store.dart';
import 'html_game_surface.dart';
import 'html_visibility_observer.dart';
import 'html_route_observer.dart';

class HtmlGameView extends StatefulWidget {
  const HtmlGameView({
    super.key,
    required this.card,
    required this.messageId,
    required this.conversationId,
    required this.store,
    this.fullscreen = false,
    this.backLabel = '返回会话',
  });
  final HtmlGameCard card;
  final String messageId;
  final String conversationId;
  final HtmlGameStore store;
  final bool fullscreen;
  final String backLabel;

  Future<HtmlGameCard> captureForwardPreview() async {
    final view = _HtmlGameViewState._views
        .where(
          (view) =>
              view.widget.messageId == messageId &&
              view.widget.fullscreen == fullscreen,
        )
        .firstOrNull;
    await view?._session?.capture();
    return store.card(messageId);
  }

  Future<void> openFullscreen(BuildContext context) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => HtmlGameView(
            card: card,
            messageId: messageId,
            conversationId: conversationId,
            store: store,
            fullscreen: true,
            backLabel: backLabel,
          ),
        ),
      );
  @override
  State<HtmlGameView> createState() => _HtmlGameViewState();
}

class _HtmlGameViewState extends State<HtmlGameView>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  Timer? _idleTimer;
  int _openRevision = 0;
  static final _heights = <(String, double, bool, double, int), double>{};
  @override
  bool get wantKeepAlive => _session != null || _opening || _closing != null;
  final _anchor = GlobalKey();
  HtmlGameSession? _session;
  static final _views = <_HtmlGameViewState>{};
  ScrollPosition? _scroll;
  bool _checkScheduled = false;
  late final StreamSubscription<String> _changes;
  late final StreamSubscription<String> _appChanges;
  late HtmlGameCard _card;
  Uint8List? _preview;
  double? _contentHeight;
  (double, double, double, int)? _savedSize;
  (String, double, bool, double, int)? _heightKey;
  bool _surfaceReady = false;
  bool _opening = false, _retrying = false;
  bool _failed = false, _foreground = true, _leaving = false;
  bool _tabVisible = true;
  Future<void>? _closing;

  @override
  void initState() {
    super.initState();
    _card = widget.card;
    _preview = _card.preview;
    _appChanges = HtmlGameSignals.appChanges.stream
        .where((id) => id == _card.appId)
        .listen((_) => unawaited(_refreshCard()));
    _changes = HtmlGameSignals.changes.stream
        .where((id) => id == widget.messageId)
        .listen((_) => unawaited(_refreshCard()));
    WidgetsBinding.instance.addObserver(this);
    _views.add(this);
    htmlRouteObserver.addListener(_scheduleVisibility);
    _scheduleVisibility();
  }

  // A stored preview is optional; the live document supplies its height.
  void _scheduleVisibility() {
    if (!mounted || _checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (mounted) _checkVisibility();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tabVisible = TickerMode.valuesOf(context).enabled;
    ModalRoute.isCurrentOf(context);
    unawaited(_session?.updateTheme(Theme.of(context)));
    final scroll = widget.fullscreen || _card.displayMode == 'standalone'
        ? null
        : Scrollable.maybeOf(context)?.position;
    if (scroll != _scroll) {
      _scroll?.removeListener(_scheduleVisibility);
      _scroll?.isScrollingNotifier.removeListener(_scheduleVisibility);
      _scroll = scroll;
      _scroll?.addListener(_scheduleVisibility);
      _scroll?.isScrollingNotifier.addListener(_scheduleVisibility);
    }
    _scheduleVisibility();
  }

  @override
  void didChangeMetrics() => _scheduleVisibility();

  @override
  void didUpdateWidget(HtmlGameView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.card.version > _card.version) {
      _card = widget.card;
      _preview = _card.preview;
    }
  }

  bool get _visible {
    if ((!widget.fullscreen && _card.displayMode == 'standalone') ||
        !mounted ||
        _leaving ||
        !_foreground ||
        !_tabVisible ||
        !htmlRouteObserver.isVisible(ModalRoute.of(context)!))
      return false;
    if (widget.fullscreen) return true;
    final box = _anchor.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return false;
    // Keyboard occlusion must not destroy a live form and dismiss its input.
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final media = MediaQuery.of(context);
    final margin = _session == null ? 0.0 : 160.0;
    return rect.bottom > media.padding.top + 80 - margin &&
        rect.top <
            media.size.height -
                (_session == null ? media.viewInsets.bottom : 0) -
                media.padding.bottom -
                80 +
                margin;
  }

  void _checkVisibility() {
    if (!_visible) {
      if (_leaving || !htmlRouteObserver.isVisible(ModalRoute.of(context)!)) {
        if (_session != null) unawaited(_close());
      } else {
        unawaited(_session?.setVisible(false));
        if (_session != null) {
          _idleTimer ??= Timer(const Duration(minutes: 1), () {
            _idleTimer = null;
            if (mounted && !_visible) unawaited(_close());
          });
        }
      }
      return;
    }
    _idleTimer?.cancel();
    _idleTimer = null;
    if (_session != null) {
      unawaited(_session!.setVisible(true));
      return;
    }
    // Visible cards start opening during scrolling; _open rechecks visibility after loading.
    if (!_opening && !_failed && _closing == null && Platform.isAndroid) {
      unawaited(_open());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Native input can temporarily take window focus while the app stays visible.
    _foreground =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    _checkVisibility();
  }

  @override
  void didHaveMemoryPressure() {
    HtmlGameDisplayCache.releaseContent();
    if (!_visible) {
      _openRevision++;
      _idleTimer?.cancel();
      _idleTimer = null;
      unawaited(_close());
    }
  }

  void _notice(String message) {
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showGlassSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _refreshCard() async {
    try {
      final next = await widget.store.card(widget.messageId);
      if (mounted && next.version >= _card.version) {
        setState(() {
          _card = next;
          _preview = next.preview;
        });
      }
    } on Object {
      await _close();
    }
  }

  Future<void> _open() async {
    if (_opening || _session != null) return;
    if (!Platform.isAndroid) {
      _notice('当前设备暂不支持 HTML 消息');
      return;
    }
    final revision = ++_openRevision;
    final previous = _views
        .where(
          (view) =>
              !identical(view, this) &&
              view.widget.messageId == widget.messageId &&
              (view._session != null || view._opening),
        )
        .firstOrNull;
    setState(() {
      _opening = true;
      _failed = false;
    });
    updateKeepAlive();
    try {
      if (previous != null) {
        previous._openRevision++;
        await previous._close();
      }
      final game = await HtmlGameDisplayCache.load(
        widget.store,
        widget.conversationId,
        widget.messageId,
      );
      if (!_visible || revision != _openRevision) return;
      final session = HtmlGameSession(
        game,
        widget.store,
        fullscreen: widget.fullscreen,
        theme: Theme.of(context),
      );
      setState(() {
        _surfaceReady = false;
        _session = session..addListener(_sessionChanged);
      });
    } on Object catch (caughtError) {
      if (mounted) setState(() => _failed = true);
      _notice('卡片加载失败，请点击重试：${errorMessage(caughtError)}');
    } finally {
      if (mounted) {
        setState(() => _opening = false);
        updateKeepAlive();
        _scheduleVisibility();
      }
      for (final view in _views) {
        if (!identical(view, this)) view._scheduleVisibility();
      }
    }
  }

  void _sessionChanged() {
    final session = _session!;
    var changed = _surfaceReady != session.ready;
    _surfaceReady = session.ready;
    // Keep the saved dimensions while the document and its state are loading.
    if (session.ready && session.contentHeight != null) {
      if (_contentHeight == null ||
          (session.contentHeight! - _contentHeight!).abs() >= 2) {
        _contentHeight = session.contentHeight;
        changed = true;
      }
      if (!widget.fullscreen && _heightKey != null) {
        final size = (
          _heightKey!.$2,
          _contentHeight!,
          MediaQuery.textScalerOf(context).scale(1),
          session.game.version,
        );
        if (_savedSize != size) {
          _savedSize = size;
          unawaited(
            widget.store
                .saveMeasuredSize(
                  widget.messageId,
                  size.$1,
                  size.$2,
                  size.$3,
                  size.$4,
                )
                .catchError((Object error) {
                  if (_savedSize == size) _savedSize = null;
                  if (mounted) _notice('尺寸保存失败：${errorMessage(error)}');
                }),
          );
        }
      }
      if (_heightKey != null) {
        _heights.remove(_heightKey);
        _heights[_heightKey!] = _contentHeight!;
      }
      if (_heights.length > 128) _heights.remove(_heights.keys.first);
    }
    if (session.failed && session.error == null) {
      unawaited(
        _close().then((_) {
          _failed = false;
          _scheduleVisibility();
        }),
      );
      return;
    }
    if (session.error != null) {
      _notice(session.error!);
      session.error = null;
      if (session.failed) {
        _failed = true;
        unawaited(_close());
      }
    }
    if (mounted && changed) setState(() {});
  }

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await widget.store.retryNotifications(widget.messageId);
      HtmlGameSignals.changes.add(widget.messageId);
      _notice('已重新排队，AI 空闲后会继续');
    } on Object catch (error) {
      _notice('未能重新通知：${errorMessage(error)}');
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  Future<void> _close() => _closing ??= _closeSession().whenComplete(() {
    _closing = null;
    if (mounted) {
      updateKeepAlive();
      _scheduleVisibility();
    }
  });
  Future<void> _closeSession() async {
    final session = _session;
    if (session == null) return;
    session.removeListener(_sessionChanged);
    await session.close();
    if (session.previewVersion == session.game.version &&
        session.preview != null)
      _preview = session.preview;
    _session = null;
    if (mounted) setState(() {});
    for (final view in _views) {
      view._scheduleVisibility();
    }
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    htmlRouteObserver.removeListener(_scheduleVisibility);
    _views.remove(this);
    _scroll?.removeListener(_scheduleVisibility);
    _scroll?.isScrollingNotifier.removeListener(_scheduleVisibility);
    _changes.cancel();
    _appChanges.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_close());
    super.dispose();
  }

  Future<void> _leaveFullscreen() async {
    if (_leaving) return;
    _leaving = true;
    try {
      await _close();
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Widget _fullscreen() => PopScope<void>(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(_leaveFullscreen());
    },
    child: Scaffold(
      body: SafeArea(
        child: Stack(
          key: _anchor,
          fit: StackFit.expand,
          children: [
            if (_session != null)
              Padding(
                padding: const EdgeInsets.only(top: 64),
                child: HtmlGameSurface(
                  session: _session!,
                  borderRadius: BorderRadius.zero,
                ),
              )
            else
              Center(
                child: _failed
                    ? TextButton(onPressed: _open, child: const Text('重试'))
                    : const CircularProgressIndicator(strokeWidth: 2),
              ),
            if (_session != null)
              Positioned(
                top: 12,
                right: 16,
                child: MiniappFavoriteAction(
                  appId: _session!.game.appId,
                  store: widget.store,
                ),
              ),
            Positioned(
              top: 12,
              left: 16,
              child: SettingsGlassAction(
                label: widget.backLabel,
                icon: Icons.arrow_back_ios_new_rounded,
                onPressed: _leaveFullscreen,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final content = widget.fullscreen
        ? _buildView(context)
        : Material(
            color: _card.backgroundMode == 'transparent'
                ? Colors.transparent
                : Theme.of(context).brightness == Brightness.dark
                ? const Color(0xff2a292f)
                : const Color(0xffefeff3),
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: _buildView(context),
          );
    return widget.fullscreen || _card.displayMode == 'standalone'
        ? content
        : HtmlVisibilityObserver(
            onChanged: _scheduleVisibility,
            child: content,
          );
  }

  Widget _buildView(BuildContext context) => widget.fullscreen
      ? _fullscreen()
      : _card.displayMode == 'standalone'
      ? Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => widget.openFullscreen(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_preview != null)
                  Image.memory(
                    _preview!,
                    height: 160,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _card.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const SettingsIcon(type: SettingsIconType.chevron),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
      : LayoutBuilder(
          builder: (context, constraints) {
            final width = math.min(
              _card.width?.toDouble() ?? constraints.maxWidth,
              constraints.maxWidth,
            );
            // Keep the document at its measured layout width across surfaces.
            final layoutWidth =
                (_card.measuredVersion == _card.version
                    ? _card.measuredWidth
                    : null) ??
                (_heightKey?.$5 == _card.version ? _heightKey?.$2 : null) ??
                width;
            final key = (
              widget.messageId,
              layoutWidth,
              widget.fullscreen,
              MediaQuery.textScalerOf(context).scale(1),
              _card.version,
            );
            if (_heightKey != key) {
              final previousKey = _heightKey;
              final previousHeight = _contentHeight;
              _heightKey = key;
              _contentHeight =
                  _heights[key] ??
                  (previousKey != null &&
                          previousKey.$2 == key.$2 &&
                          previousKey.$3 == key.$3 &&
                          previousKey.$4 == key.$4
                      ? previousHeight
                      : null);
              if (_contentHeight == null &&
                  !widget.fullscreen &&
                  _card.measuredWidth == layoutWidth &&
                  _card.measuredScale ==
                      MediaQuery.textScalerOf(context).scale(1) &&
                  _card.measuredVersion == _card.version) {
                _contentHeight = _card.measuredHeight;
              }
            }
            final documentHeight =
                _contentHeight ??
                (_card.measuredVersion == _card.version
                    ? _card.measuredHeight
                    : null) ??
                _card.height.toDouble();
            final height = documentHeight * width / layoutWidth;
            return SizedBox(
              key: _anchor,
              width: math.min(
                _card.width?.toDouble() ?? constraints.maxWidth,
                constraints.maxWidth,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_session != null)
                    // Resizing the native surface should not animate its clip.
                    SizedBox(
                      height: height,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: layoutWidth,
                          height: documentHeight,
                          child: HtmlGameSurface(
                            session: _session!,
                            preview: _preview,
                            loadingBackground:
                                _card.backgroundMode == 'transparent'
                                ? Colors.transparent
                                : Theme.of(context).brightness ==
                                      Brightness.dark
                                ? const Color(0xff2a292f)
                                : const Color(0xffefeff3),
                          ),
                        ),
                      ),
                    )
                  else if (_preview != null && !_failed)
                    GestureDetector(
                      onTap: _open,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _preview!,
                          gaplessPlayback: true,
                          height: height,
                          fit: BoxFit.fitWidth,
                          alignment: Alignment.topCenter,
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: height,
                      child: Center(
                        child: _failed
                            ? TextButton(
                                onPressed: _open,
                                child: const Text('加载失败，点击重试'),
                              )
                            : const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                      ),
                    ),
                  if (_card.canRetry)
                    TextButton(
                      onPressed: _retrying ? null : _retry,
                      child: const Text('重试 AI 回合'),
                    ),
                ],
              ),
            );
          },
        );
}
