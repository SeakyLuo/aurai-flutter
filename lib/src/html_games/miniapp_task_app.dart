import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../app/appearance_settings.dart';
import '../app/glass_notice.dart';
import '../app/global_ui.dart';
import '../domain/error_message.dart';
import '../features/chat/attachment_action_icon.dart';
import '../features/chat/header_action_menu.dart';
import '../features/chat/settings_appearance.dart';
import '../features/chat/settings_icon.dart';
import 'miniapp_favorite_action.dart';

/// Dormant UI entry: enabled only by MiniappTaskHost.openApp/openMessage.
class MiniappTaskApp extends StatelessWidget {
  const MiniappTaskApp({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: AppearanceSettings.instance,
    builder: (context, _) => MaterialApp(
      navigatorKey: AppToasts.navigatorKey,
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: GlobalUI.theme,
      darkTheme: GlobalUI.darkTheme,
      themeMode: AppearanceSettings.instance.mode,
      home: const _TaskPage(),
    ),
  );
}

class _TaskPage extends StatefulWidget {
  const _TaskPage();
  @override
  State<_TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<_TaskPage> with WidgetsBindingObserver {
  static const _channel = MethodChannel('aurai/miniapp_tasks');
  Map<String, Object?>? _surface;
  bool _starting = false, _ready = false, _busy = false, _closing = false;
  bool _visible = true, _hasApp = false;
  String? _lastError;

  Future<T?> _request<T>(String method, [Object? arguments]) => _channel
      .invokeMethod<T>('request', {'method': method, 'arguments': arguments});

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'state') throw MissingPluginException(call.method);
      if (!mounted || _closing) return;
      final state = call.arguments as Map;
      if (state['finished'] == true) {
        await _close();
        return;
      }
      setState(() => _ready = state['ready'] == true);
      final error = state['error'] as String?;
      if (error != null && error != _lastError) {
        _lastError = error;
        _notice(error);
      }
      if (state['failed'] == true) await _close();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_starting) {
      _starting = true;
      unawaited(_prepare());
    } else if (_surface != null) {
      unawaited(
        _run(
          () => _request(
            'theme',
            Theme.of(context).brightness == Brightness.dark,
          ),
        ),
      );
    }
  }

  void _notice(String text, {ToastKind kind = ToastKind.error}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppToasts.show(SnackBar(content: Text(text)), kind: kind);
    });
  }

  Future<void> _run(Future<Object?> Function() action) async {
    try {
      await action();
    } on Object catch (error) {
      if (mounted) _notice(errorMessage(error));
    }
  }

  Future<void> _prepare() async {
    try {
      await AppearanceSettings.instance.load();
      if (!mounted) return;
      final dark =
          AppearanceSettings.instance.mode == ThemeMode.dark ||
          (AppearanceSettings.instance.mode == ThemeMode.system &&
              MediaQuery.platformBrightnessOf(context) == Brightness.dark);
      final padding = MediaQuery.paddingOf(context);
      final description = (await _request<Map>('prepare', {
        'dark': dark,
        'visible': _visible,
        'topInset': padding.top + SettingsAppBar.toolbarHeight,
        'safeTopInset': padding.top,
        'safeBottomInset': padding.bottom,
      }))!;
      await _channel.invokeMethod<void>('description', description);
      if (!mounted || _closing) return;
      setState(() {
        _surface = (description['surface'] as Map).cast<String, Object?>();
        _hasApp = description['hasApp'] as bool;
      });
      await _request<void>('visibility', _visible);
    } on Object catch (error) {
      if (mounted) _notice(errorMessage(error));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _visible =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    if (_surface != null && !_closing)
      unawaited(_run(() => _request('visibility', _visible)));
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    try {
      await _request<void>('close');
    } on Object catch (error) {
      _closing = false;
      if (mounted) _notice(errorMessage(error));
      return;
    }
    await _channel.invokeMethod<void>('finish');
  }

  Future<void> _more(BuildContext anchor) async {
    setState(() => _busy = true);
    try {
      final starred = (await _request<bool>('favoriteStatus'))!;
      if (!anchor.mounted) return;
      final action = await showHeaderActionMenu(
        anchor,
        items: [
          (
            value: 'forward',
            label: '分享',
            icon: const AttachmentActionIcon(
              type: AttachmentActionIconType.forward,
            ),
          ),
          (
            value: 'favorite',
            label: starred ? '取消收藏' : '收藏',
            icon: SettingsIcon(
              type: starred
                  ? SettingsIconType.starFilled
                  : SettingsIconType.star,
            ),
          ),
          (
            value: 'details',
            label: '小程序详情',
            icon: const SettingsIcon(type: SettingsIconType.info),
          ),
        ],
      );
      if (action == null) return;
      await _request<void>(action, action == 'favorite' ? !starred : null);
      if (action == 'favorite' && mounted) {
        _notice(starred ? '已取消收藏小程序' : '已收藏小程序', kind: ToastKind.success);
      }
    } on Object catch (error) {
      if (mounted) _notice(errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(_close());
    },
    child: Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_surface != null)
            AndroidView(
              viewType: 'aurai/html_game',
              creationParams: _surface,
              creationParamsCodec: const StandardMessageCodec(),
              gestureRecognizers: {
                Factory<OneSequenceGestureRecognizer>(
                  () => EagerGestureRecognizer(),
                ),
              },
              onPlatformViewCreated: (_) =>
                  unawaited(_run(() => _request('bind'))),
            ),
          if (!_ready)
            ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: const Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          Positioned(
            top: MediaQuery.paddingOf(context).top,
            right: 16,
            height: SettingsAppBar.toolbarHeight,
            child: Center(
              child: MiniappActionSurface(
                onClose: _close,
                onMore: !_hasApp || _busy ? null : _more,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
