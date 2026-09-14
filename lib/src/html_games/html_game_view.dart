import '../domain/error_message.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../features/chat/settings_appearance.dart';
import '../features/chat/settings_icon.dart';
import 'html_game.dart';
import 'html_game_icon.dart';
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
  });
  final HtmlGameCard card;
  final String messageId;
  final String conversationId;
  final HtmlGameStore store;
  final bool fullscreen;

  Future<void> openFullscreen(BuildContext context) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => HtmlGameView(
            card: card,
            messageId: messageId,
            conversationId: conversationId,
            store: store,
            fullscreen: true,
          ),
        ),
      );
  @override
  State<HtmlGameView> createState() => _HtmlGameViewState();
}

class _HtmlGameViewState extends State<HtmlGameView>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  static _HtmlGameViewState? _active;
  static int _openRevision = 0;
  static final _heights = <String, double>{};
  Timer? _offscreenTimer;
  @override
  bool get wantKeepAlive => _session != null || _opening || _closing != null;
  final _anchor = GlobalKey();
  HtmlGameSession? _session;
  static final _views = <_HtmlGameViewState>{};
  ScrollPosition? _scroll;
  bool _checkScheduled = false;
  late final StreamSubscription<String> _changes;
  late HtmlGameCard _card;
  Uint8List? _preview;
  double? _contentHeight;
  bool _opening = false, _expanded = false, _retrying = false;
  bool _failed = false, _foreground = true, _leaving = false;
  Future<void>? _closing;

  @override
  void initState() {
    super.initState();
    _card = widget.card;
    _preview = _card.preview;
    _contentHeight = _heights[widget.messageId];
    _changes = HtmlGameSignals.changes.stream
        .where((id) => id == widget.messageId)
        .listen((_) => unawaited(_refreshCard()));
    WidgetsBinding.instance.addObserver(this);
    _views.add(this);
    htmlRouteObserver.addListener(_scheduleVisibility);
    _scheduleVisibility();
  }

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
    ModalRoute.isCurrentOf(context);
    final scroll = widget.fullscreen || _card.displayMode == 'standalone'
        ? null
        : Scrollable.maybeOf(context)?.position;
    if (scroll != _scroll) {
      _scroll?.removeListener(_scheduleVisibility);
      _scroll = scroll;
      _scroll?.addListener(_scheduleVisibility);
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
        !htmlRouteObserver.isVisible(ModalRoute.of(context)!))
      return false;
    if (widget.fullscreen) return true;
    final box = _anchor.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return false;
    // Keyboard occlusion must not destroy a live form and dismiss its input.
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final media = MediaQuery.of(context);
    return rect.bottom > media.padding.top + 80 &&
        rect.top <
            media.size.height -
                (_session == null ? media.viewInsets.bottom : 0) -
                media.padding.bottom -
                80;
  }

  void _checkVisibility() {
    if (!_visible) {
      if (!_foreground ||
          _leaving ||
          !htmlRouteObserver.isVisible(ModalRoute.of(context)!)) {
        _offscreenTimer?.cancel();
        _offscreenTimer = null;
        if (_session != null) unawaited(_close());
      } else if (_session != null && _offscreenTimer == null) {
        _offscreenTimer = Timer(const Duration(milliseconds: 350), () {
          _offscreenTimer = null;
          if (mounted && !_visible) unawaited(_close());
        });
      }
      return;
    }
    _offscreenTimer?.cancel();
    _offscreenTimer = null;
    if (_active == null &&
        !_opening &&
        !_failed &&
        _closing == null &&
        Platform.isAndroid) {
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

  void _notice(String message) {
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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
    final previous = _active;
    _active = this;
    setState(() {
      _opening = true;
      _failed = false;
    });
    updateKeepAlive();
    try {
      await previous?._close();
      final game = await widget.store.load(
        widget.conversationId,
        widget.messageId,
      );
      final local = await HtmlGameSession.loadLocal(widget.messageId);
      if (!_visible || revision != _openRevision) return;
      final session = HtmlGameSession(
        game,
        widget.store,
        localState: local,
        fullscreen: widget.fullscreen,
        dark: Theme.of(context).brightness == Brightness.dark,
      );
      setState(() {
        _session = session..addListener(_sessionChanged);
      });
    } on Object catch (caughtError) {
      if (mounted) setState(() => _failed = true);
      _notice('卡片加载失败，请点击重试：${errorMessage(caughtError)}');
    } finally {
      if (_session == null && identical(_active, this)) _active = null;
      if (mounted) {
        setState(() => _opening = false);
        updateKeepAlive();
      }
    }
  }

  void _sessionChanged() {
    final session = _session!;
    if (session.contentHeight != null) {
      _contentHeight = session.contentHeight;
      _heights.remove(widget.messageId);
      _heights[widget.messageId] = _contentHeight!;
      if (_heights.length > 128) _heights.remove(_heights.keys.first);
    }
    if (session.error != null) {
      _notice(session.error!);
      session.error = null;
      if (session.failed) {
        _failed = true;
        unawaited(_close());
      }
    }
    if (mounted) setState(() {});
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
    if (mounted) updateKeepAlive();
  });
  Future<void> _closeSession() async {
    final session = _session;
    if (session == null) return;
    session.removeListener(_sessionChanged);
    await session.close();
    if (session.previewVersion == session.game.version)
      _preview = session.preview;
    _session = null;
    if (identical(_active, this)) _active = null;
    if (mounted) setState(() {});
    for (final view in _views) {
      view._scheduleVisibility();
    }
  }

  @override
  void dispose() {
    _offscreenTimer?.cancel();
    htmlRouteObserver.removeListener(_scheduleVisibility);
    _views.remove(this);
    _scroll?.removeListener(_scheduleVisibility);
    _changes.cancel();
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
            Positioned(
              top: 12,
              left: 16,
              child: SettingsGlassAction(
                label: '返回会话',
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
    return widget.fullscreen || _card.displayMode == 'standalone'
        ? _buildView(context)
        : HtmlVisibilityObserver(
            onChanged: _scheduleVisibility,
            child: _buildView(context),
          );
  }

  Widget _buildView(BuildContext context) => widget.fullscreen
      ? _fullscreen()
      : _card.displayMode == 'standalone'
      ? Material(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
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
                      const HtmlGameIcon(HtmlGameIconType.game),
                      const SizedBox(width: 10),
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
            final limit = _expanded
                ? 640.0
                : math.min(_card.height.toDouble(), 420.0);
            final height = math
                .min(_contentHeight ?? 96, limit)
                .clamp(64.0, 640.0);
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
                    SizedBox(
                      height: height,
                      child: HtmlGameSurface(session: _session!),
                    )
                  else if (_preview != null && !_failed)
                    GestureDetector(
                      onTap: _open,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _preview!,
                          height: height,
                          fit: BoxFit.fitWidth,
                          alignment: Alignment.topCenter,
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: height,
                      child: InkWell(
                        onTap: _opening ? null : _open,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              const HtmlGameIcon(HtmlGameIconType.game),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _card.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _opening
                                    ? '加载中'
                                    : _failed
                                    ? '重试'
                                    : '点击交互',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if ((_contentHeight ?? 0) >
                      math.min(_card.height.toDouble(), 420.0))
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(() => _expanded = !_expanded),
                        child: Text(_expanded ? '收起' : '展开'),
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
