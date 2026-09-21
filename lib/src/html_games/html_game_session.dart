import 'miniapp_library_store.dart';
import 'html_ai_service.dart';
import '../storage/html_callback_state.dart';
import '../storage/message_callbacks.dart';
import 'html_app_store.dart';
import '../storage/interactive_message_store.dart';
import 'package:flutter/material.dart';
import 'html_message_theme.dart';
import 'html_game_display_cache.dart';
import 'html_message_interaction.dart';
import '../domain/error_message.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../domain/message_sender.dart';
import 'html_game.dart';
import 'html_game_document.dart';
import 'html_game_store.dart';

abstract final class HtmlGameSignals {
  static final callbackChanges = HtmlCallbackState.changes;
  static final changes = StreamController<String>.broadcast();
  static final appChanges = StreamController<String>.broadcast();
}

class HtmlGameSession extends ChangeNotifier {
  HtmlGameSession(
    this.game,
    this.store, {
    this.localState = const [],
    required this.theme,
    this.fullscreen = false,
    this.independent = false,
  }) {
    _readyTimeout = Timer(const Duration(seconds: 15), () {
      if (!_closed && !ready) {
        failed = true;
        error = '卡片加载超时，请重试';
        notifyListeners();
      }
    });
    _interactiveUpdates = InteractiveMessageStore.changes.stream
        .where((id) => id == game.messageId)
        .listen((_) => unawaited(_reload()));
    _appUpdates = HtmlGameSignals.appChanges.stream
        .where((id) => id == game.appId)
        .listen((_) => unawaited(_reload()));
    _callbackUpdates = HtmlCallbackState.changes.stream
        .where((id) => id == game.messageId)
        .listen((_) => unawaited(_sendCallbacks()));
    _updates = HtmlGameSignals.changes.stream
        .where((id) => id == game.messageId)
        .listen((_) => unawaited(_reload()));
  }
  static final _preferences = SharedPreferencesAsync();
  static Future<List<Object?>> loadLocal(String id) async {
    final saved = await _preferences.getString('html_form:$id');
    return saved == null ? [] : jsonDecode(saved) as List<Object?>;
  }

  final List<Object?> localState;
  ThemeData theme;
  bool _editing = false;
  HtmlGame? _pendingUpdate;
  final bool fullscreen;
  final bool independent;
  late final Timer _readyTimeout;
  Future<void> _localWrite = Future.value();
  Timer? _captureTimer;
  bool _capturing = false;
  String? _lastLocalState;
  double? contentHeight;
  List<Rect> gestureRegions = const [];
  bool failed = false;
  HtmlGame game;
  final HtmlGameStore store;
  late final StreamSubscription<String> _updates;
  late final StreamSubscription<String> _callbackUpdates;
  late final StreamSubscription<String> _appUpdates;
  late final StreamSubscription<String> _interactiveUpdates;
  final _ai = HtmlAiService();
  MethodChannel? _channel;
  bool _closed = false;
  bool _closing = false;
  bool ready = false;
  bool _visible = true;
  bool _pageLoaded = false;
  String? error;
  Uint8List? preview;
  int? previewVersion;
  late final String identity =
      '${HtmlGameDisplayCache.identity(game)}:fixed-height-v1';
  String? _document;
  Future<String> _loadDocument() async {
    final local = await loadLocal(game.messageId);
    return _document ??= htmlGameDocument(
      game,
      theme: theme,
      localState: local,
      fullscreen: fullscreen,
    );
  }

  Future<void> bind(int id) async {
    final channel = MethodChannel('aurai/html_game/$id');
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      if (_closed || (_closing && call.method != 'localState'))
        return jsonEncode({'error': '游戏已暂停'});
      if (call.method == 'requestDocument') {
        final document = await _loadDocument();
        if (!_closed && !_closing)
          await channel.invokeMethod<void>('loadDocument', document);
      } else if (call.method == 'editing') {
        _editing = call.arguments as bool;
        if (!_editing && _pendingUpdate != null) {
          final next = _pendingUpdate!;
          _pendingUpdate = null;
          try {
            await _applyUpdate(next);
          } on Object catch (failure) {
            error = '卡片更新失败：${errorMessage(failure)}';
            notifyListeners();
          }
        }
      } else if (call.method == 'scriptError') {
        error = 'HTML 消息：${call.arguments}';
        notifyListeners();
      } else if (call.method == 'visualChanged') {
        _captureTimer?.cancel();
        _captureTimer = Timer(
          const Duration(milliseconds: 500),
          () => unawaited(capture()),
        );
      } else if (call.method == 'height') {
        final height = (call.arguments as num).toDouble();
        if (height.isFinite &&
            height > 0 &&
            (height - (contentHeight ?? 0)).abs() >= 2) {
          contentHeight = height;
          notifyListeners();
        }
      } else if (call.method == 'gestureRegions') {
        gestureRegions = (jsonDecode(call.arguments as String) as List)
            .map(
              (r) => Rect.fromLTWH(
                (r[0] as num).toDouble(),
                (r[1] as num).toDouble(),
                (r[2] as num).toDouble(),
                (r[3] as num).toDouble(),
              ),
            )
            .toList();
      } else if (call.method == 'reopen') {
        failed = true;
        error = '操作尚未确认，请点击重试以读取最新状态';
        notifyListeners();
      } else if (call.method == 'localState') {
        final encoded = call.arguments as String;
        if (encoded == _lastLocalState) return null;
        _lastLocalState = encoded;
        _localWrite = _localWrite.then((_) async {
          try {
            await _preferences.setString(
              'html_form:${game.messageId}',
              encoded,
            );
          } on Object catch (caughtError) {
            _lastLocalState = null;
            if (!_closed) {
              error = '输入内容保存失败，请勿关闭卡片：${errorMessage(caughtError)}';
              notifyListeners();
            }
          }
        });
        await _localWrite;
      } else if (call.method == 'ready') {
        _pageLoaded = true;
        // Android's state acknowledgement waits for a visual frame; only then
        // may the view remove the previous preview covering the platform surface.
        await channel.invokeMethod<void>('theme', htmlMessageTheme(theme));
        await channel.invokeMethod<void>('state', jsonEncode(game.snapshot()));
        await _sendCallbacks();
        if (_closed || _closing) return null;
        _readyTimeout.cancel();
        ready = true;
        if (!_visible) await channel.invokeMethod<void>('visibility', false);
        notifyListeners();
        unawaited(capture());
      } else if (call.method == 'failed') {
        failed = true;
        error = 'HTML 消息运行中断：${call.arguments}';
        notifyListeners();
      } else if (call.method == 'ai') {
        if (!_visible) return jsonEncode({'error': '请打开小程序后使用 AI', 'code': 'inactive'});
        final args = (call.arguments as Map).cast<String, Object?>();
        final id = args['id'] as int;
        return jsonEncode(await _ai.invoke(id, args['request'] as String, onText: (text) {
          if (!_closed && !_closing) {
            unawaited(channel.invokeMethod<void>('aiUpdate', jsonEncode({'id': id, 'text': text})).catchError((Object _) {}));
          }
        }));
      } else if (call.method == 'cancelAi') {
        await _ai.cancel(call.arguments as int);
      } else if (call.method == 'appData') {
        try {
          final args = (jsonDecode(call.arguments as String) as Map).cast<String, Object?>();
          if (args['operation'] == 'events' || args['operation'] == 'retryEvent') {
            if (independent) {
              if (args['operation'] == 'retryEvent') throw StateError('请从原会话打开小程序后重试');
              return jsonEncode({'events': <Object?>[]});
            }
            final eventId = args['eventId'] as String?;
            if (args['operation'] == 'retryEvent') {
              await HtmlCallbackState.retry(store.database, game.messageId, eventId!);
              MessageCallbacks.changes.add(null);
            }
            return jsonEncode({'events': await HtmlCallbackState.read(
              store.database, game.messageId, eventId: eventId)});
          }
          final write = args['operation'] == 'write';
          if (!['read', 'write'].contains(args['operation'])) {
            throw ArgumentError('不支持的数据操作');
          }
          final result = await HtmlAppStore(store.database).data(
            game.appId, args['name'] as String, actor: independent ? game.creatorId : MessageSender.localUser.id,
            messageId: independent ? null : game.messageId, write: write,
            expectedRevision: args['expectedRevision'] as int?, value: args['value']);
          if (write) HtmlGameSignals.appChanges.add(game.appId);
          return jsonEncode(result);
        } on Object catch (failure) {
          return jsonEncode({'error': errorMessage(failure)});
        }
      } else if (call.method == 'interaction') {
        try {
          if (independent) {
            error = '此操作需要从原会话打开小程序';
            notifyListeners();
            return jsonEncode({'error': error});
          }
          return jsonEncode(
            await store.submitInteraction(
              game.conversationId,
              game.messageId,
              (jsonDecode(call.arguments as String) as Map)
                  .cast<String, Object?>(),
            ),
          );
        } on Object catch (failure) {
          return jsonEncode({'error': errorMessage(failure)});
        }
      } else if (call.method == 'event') {
        try {
          if (independent) throw StateError('此操作需要从原会话打开小程序');
          final args = (jsonDecode(call.arguments as String) as Map)
              .cast<String, Object?>();
          final result = await store.apply(
            game.conversationId,
            game.messageId,
            MessageSender.localUser.id,
            args,
          );
          await _reload();
          HtmlGameSignals.changes.add(game.messageId);
          return jsonEncode(result);
        } on Object catch (failure) {
          error = switch (failure) {
            StateError() => failure.message,
            ArgumentError() => '${failure.message}',
            _ => errorMessage(failure),
          };
          notifyListeners();
          return jsonEncode({'error': error});
        }
      }
      return null;
    });
    await channel.invokeMethod<void>('connect');
  }

  Future<void> _sendCallbacks() async {
    try {
      if (!_pageLoaded || _closed || _closing || independent) return;
      final events = await HtmlCallbackState.read(store.database, game.messageId);
      if (!_closed && !_closing) {
        await _channel?.invokeMethod<void>('callbacks', jsonEncode(events));
      }
    } on Object catch (failure) {
      if (!_closed) {
        error = '无法读取操作状态：${errorMessage(failure)}';
        notifyListeners();
      }
    }
  }

  bool _isNewer(HtmlGame next) {
    if (next.version != game.version) return next.version > game.version;
    final incoming = next.interactionProjection;
    final current = game.interactionProjection;
    if (incoming == null) return false;
    if (current == null) return true;
    for (final key in [
      'revision',
      'sessionVersion',
      'participantRevision',
      'callbackVersion',
    ]) {
      if (incoming[key] != current[key])
        return (incoming[key] as int) > (current[key] as int);
    }
    return false;
  }

  Future<void> _reload() async {
    try {
      final next = independent
          ? await MiniappLibraryStore(store.database).loadIndependent(game.appId)
          : await store.load(game.conversationId, game.messageId);
      if (_closed || _closing || !_isNewer(next)) return;
      if (_editing && next.html != game.html) {
        if (_pendingUpdate == null || next.version > _pendingUpdate!.version)
          _pendingUpdate = next;
        return;
      }
      await _applyUpdate(next);
    } on Object catch (caughtError) {
      if (!_closed) {
        error = '无法更新 HTML 消息：${errorMessage(caughtError)}';
        notifyListeners();
      }
    }
  }

  Future<void> setVisible(bool value) async {
    if (_visible == value || _closed || _closing) return;
    _visible = value;
    if (!value) {
      _captureTimer?.cancel();
      await _ai.cancelAll();
    }
    if (ready) await _channel?.invokeMethod<void>('visibility', value);
  }

  Future<void> updateTheme(ThemeData next, {bool force = false}) async {
    if (!force && next == theme) return;
    theme = next;
    _document = null;
    if (_pageLoaded && !_closed && !_closing) {
      try {
        await _channel?.invokeMethod<void>('theme', htmlMessageTheme(theme));
      } on Object catch (failure) {
        error = '主题更新失败：${errorMessage(failure)}';
        notifyListeners();
      }
    }
  }

  Future<void> _applyUpdate(HtmlGame next) async {
    if (_closed || _closing || !_isNewer(next)) return;
    if (next.version != game.version) {
      preview = null;
      previewVersion = null;
    }
    if (next.html != game.html) {
      HtmlGameDisplayCache.invalidate(game.messageId);
      failed = true;
      error = null;
      notifyListeners();
      return;
    }
    game = next;
    if (_pageLoaded)
      await _channel?.invokeMethod<void>('state', jsonEncode(game.snapshot()));
    if (!_closed) notifyListeners();
  }

  Future<void> capture() async {
    if (independent || !ready || !_visible || _closed || _closing || _capturing) return;
    _capturing = true;
    final version = game.version;
    try {
      final bytes = await _channel
          ?.invokeMethod<Uint8List>('snapshot')
          .timeout(const Duration(seconds: 1));
      if (bytes != null &&
          bytes.length <= 256 * 1024 &&
          version == game.version) {
        preview = bytes;
        previewVersion = version;
        await store.savePreview(game.messageId, version, bytes);
      }
    } on Object {
      // A preview is optional; canonical state is already committed per action.
    } finally {
      _capturing = false;
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closing = true;
    _readyTimeout.cancel();
    _captureTimer?.cancel();
    try {
      await _ai.cancelAll();
      try {
        await _channel?.invokeMethod<void>('flushForm')
            .timeout(const Duration(seconds: 2));
      } finally {
        await _localWrite;
      }
    } finally {
      _closed = true;
      await _updates.cancel();
      await _appUpdates.cancel();
      await _callbackUpdates.cancel();
      await _interactiveUpdates.cancel();
      try {
        await _channel
            ?.invokeMethod<void>('dispose')
            .timeout(const Duration(seconds: 1));
      } on Object {
        /* The platform view may already have been removed. */
      }
      _channel?.setMethodCallHandler(null);
      dispose();
    }
  }
}
