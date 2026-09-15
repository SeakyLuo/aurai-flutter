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
  static final changes = StreamController<String>.broadcast();
}

class HtmlGameSession extends ChangeNotifier {
  HtmlGameSession(
    this.game,
    this.store, {
    this.localState = const [],
    this.dark = false,
    this.fullscreen = false,
  }) {
    _readyTimeout = Timer(const Duration(seconds: 15), () {
      if (!_closed && !ready) {
        failed = true;
        error = '卡片加载超时，请重试';
        notifyListeners();
      }
    });
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
  final bool dark;
  final bool fullscreen;
  late final Timer _readyTimeout;
  Future<void> _localWrite = Future.value();
  Timer? _captureTimer;
  bool _capturing = false;
  String? _lastLocalState;
  double? contentHeight;
  bool failed = false;
  HtmlGame game;
  final HtmlGameStore store;
  late final StreamSubscription<String> _updates;
  MethodChannel? _channel;
  bool _closed = false;
  bool _closing = false;
  bool ready = false;
  String? error;
  Uint8List? preview;
  int? previewVersion;
  late final String identity = '${HtmlGameDisplayCache.identity(game)}:$dark';
  String? _document;
  Future<String> _loadDocument() async {
    final local = await loadLocal(game.messageId);
    return _document ??= htmlGameDocument(
      game,
      dark: dark,
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
            (height - (contentHeight ?? 0)).abs() >= 1) {
          contentHeight = height;
          notifyListeners();
        }
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
        _readyTimeout.cancel();
        ready = true;
        notifyListeners();
        await channel.invokeMethod<void>('state', jsonEncode(game.snapshot()));
        unawaited(capture());
      } else if (call.method == 'failed') {
        failed = true;
        error = '游戏运行中断，请关闭后重新打开';
        notifyListeners();
      } else if (call.method == 'interaction') {
        try {
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

  Future<void> _reload() async {
    try {
      final next = await store.load(game.conversationId, game.messageId);
      if (_closed || next.version < game.version) return;
      if (next.version != game.version) {
        preview = null;
        previewVersion = null;
      }
      if (next.html != game.html) {
        failed = true;
        error = null;
        notifyListeners();
        return;
      }
      game = next;
      if (ready)
        await _channel?.invokeMethod<void>(
          'state',
          jsonEncode(game.snapshot()),
        );
      if (!_closed) notifyListeners();
    } on Object catch (caughtError) {
      if (!_closed) {
        error = '无法读取游戏，请关闭后重试：${errorMessage(caughtError)}';
        notifyListeners();
      }
    }
  }

  Future<void> capture() async {
    if (!ready || _closed || _closing || _capturing) return;
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
    await _channel?.invokeMethod<void>('flushForm');
    await _localWrite;
    _closed = true;
    await _updates.cancel();
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
