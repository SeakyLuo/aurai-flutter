import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/global_ui.dart';
import '../domain/message_sender.dart';
import '../features/chat/ai_contact_page.dart';
import '../features/chat/chat_controller.dart';
import '../features/chat/home_page.dart';
import '../features/chat/personal_info_page.dart';
import 'html_game_session.dart';
import 'miniapp_detail_page.dart';
import 'miniapp_favorites.dart';
import 'miniapp_forward.dart';
import 'miniapp_library_store.dart';
import 'miniapp_recent_store.dart';

/// UI engines never open the database or start a second chat/AI controller.
/// Their WebViews bind directly to sessions in the application's main engine.
abstract final class MiniappTaskHost {
  static const channel = MethodChannel('aurai/miniapp_tasks');
  static final _controller = Completer<ChatController>();
  static final _sessions = <String, Future<_TaskSession>>{};
  static var _channelId = -1;

  static void install() => channel.setMethodCallHandler(_handle);
  static void ready(ChatController controller) {
    if (!_controller.isCompleted) _controller.complete(controller);
  }

  // 已实现但暂不接入：openMiniapp / HtmlView.openFullscreen 继续走现有路由。
  // 未来只替换 Android 全屏入口；内嵌消息和分屏不要调用此入口。
  // appId 必须是现有 launcher 完成安装/更新后得到的 runtimeId。
  static Future<void> openApp({required String title, required String appId}) =>
      channel.invokeMethod<void>('open', {'title': title, 'appId': appId});

  static Future<void> openMessage({
    required String title,
    required String messageId,
    required String conversationId,
  }) => channel.invokeMethod<void>('open', {
    'title': title,
    'messageId': messageId,
    'conversationId': conversationId,
  });

  static Future<Object?> _handle(MethodCall call) async {
    if (call.method != 'request') throw MissingPluginException(call.method);
    final args = (call.arguments as Map).cast<String, Object?>();
    final instance = args['instance'] as String;
    final method = args['method'] as String;
    final input = args['arguments'];
    if (method == 'prepare') {
      final pending = _prepare(
        instance,
        jsonDecode(args['launch'] as String) as Map,
        input as Map,
      );
      _sessions[instance] = pending;
      final task = await pending;
      return task.description;
    }
    if (method == 'close') {
      final pending = _sessions.remove(instance);
      if (pending != null) {
        final task = await pending;
        task.session.removeListener(task.changed);
        await task.session.close();
      }
      return null;
    }
    final task = await _sessions[instance]!;
    final session = task.session;
    switch (method) {
      case 'bind':
        await session.bind(task.channelId);
      case 'visibility':
        await session.setVisible(input as bool);
      case 'theme':
        await session.updateTheme(
          input == true ? GlobalUI.darkTheme : GlobalUI.theme,
        );
      case 'favoriteStatus':
        final entry = await MiniappLibraryStore(
          session.store.database,
        ).entryForApp(session.game.appId!);
        return MiniappFavorites(session.store.database).contains(entry);
      case 'favorite':
        final entry = await MiniappLibraryStore(
          session.store.database,
        ).entryForApp(session.game.appId!);
        final favorites = MiniappFavorites(session.store.database);
        if (input == true) {
          await favorites.add(entry);
        } else {
          await favorites.remove(entry);
        }
      case 'details':
      case 'forward':
        final entry = await MiniappLibraryStore(
          session.store.database,
        ).entryForApp(session.game.appId!);
        await channel.invokeMethod<void>('showMain');
        final context = HomePage.navigationKey.currentContext!;
        if (method == 'forward') {
          await forwardMiniapp(context, entry);
        } else {
          await Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => MiniappDetailPage(
                entry: entry,
                store: session.store,
                showOpenAction: false,
              ),
            ),
          );
        }
      default:
        throw MissingPluginException(method);
    }
    return null;
  }

  static Future<_TaskSession> _prepare(
    String instance,
    Map launch,
    Map layout,
  ) async {
    final controller = await _controller.future;
    final store = controller.htmlStore;
    final messageId = launch['messageId'] as String?;
    final independent = messageId == null;
    final game = independent
        ? await MiniappLibraryStore(
            store.database,
          ).loadIndependent(launch['appId'] as String)
        : await store.load(launch['conversationId'] as String, messageId);
    final entry = game.appId == null
        ? null
        : await MiniappLibraryStore(store.database).entryForApp(game.appId!);
    final icon = entry == null ? null : await _icon(entry);
    if (game.appId != null)
      await recordMiniappOpen(store.database, game.appId!);
    final session = HtmlGameSession(
      game,
      store,
      surfaceId: 'task:$instance',
      theme: layout['dark'] == true ? GlobalUI.darkTheme : GlobalUI.theme,
      fullscreen: true,
      independent: independent,
      hostTopInset: (layout['topInset'] as num).toDouble(),
      hostSafeTopInset: (layout['safeTopInset'] as num).toDouble(),
      hostSafeBottomInset: (layout['safeBottomInset'] as num).toDouble(),
      hostRightInset: 124,
      onNextSession: independent
          ? null
          : () async {
              await HtmlGameSignals.startNextSession!(
                game.conversationId,
                game.messageId,
              );
              await channel.invokeMethod<void>('showMain');
              await channel.invokeMethod<void>('state', {
                'instance': instance,
                'state': {'finished': true},
              });
            },
      onOpenProfile: independent
          ? null
          : (senderId) async {
              await channel.invokeMethod<void>('showMain');
              await Navigator.of(
                HomePage.navigationKey.currentContext!,
              ).push<void>(
                MaterialPageRoute(
                  builder: (_) => senderId == MessageSender.localUser.id
                      ? PersonalInfoPage(memory: controller.memory)
                      : AiContactPage(
                          controller: controller,
                          senderId: senderId,
                          groupId: game.conversationId,
                        ),
                ),
              );
            },
    );
    final id = _channelId--;
    void changed() => unawaited(
      channel.invokeMethod<void>('state', {
        'instance': instance,
        'state': {
          'ready': session.ready,
          'failed': session.failed,
          'error': session.error,
        },
      }),
    );
    session.addListener(changed);
    await session.setVisible(layout['visible'] as bool);
    return _TaskSession(session, id, changed, {
      'title': entry?.title ?? launch['title'],
      'icon': icon,
      'hasApp': game.appId != null,
      'surface': {
        'channelId': id,
        'messageId': game.messageId,
        'surfaceId': session.surfaceId,
        'appId': game.appId,
        'storageKey': game.sessionScoped
            ? 'message:${game.messageId}'
            : game.appId,
        'identity': session.identity,
        'stateful': game.stateful,
        'fullscreen': true,
      },
    });
  }

  static Future<Uint8List?> _icon(MiniappEntry entry) async {
    if (entry.iconPath == null && entry.iconAsset == null) return null;
    final bytes = entry.iconPath != null
        ? await File(entry.iconPath!).readAsBytes()
        : (await rootBundle.load(entry.iconAsset!)).buffer.asUint8List();
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 96,
      targetHeight: 96,
    );
    try {
      final frame = await codec.getNextFrame();
      try {
        return (await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }
}

class _TaskSession {
  const _TaskSession(
    this.session,
    this.channelId,
    this.changed,
    this.description,
  );
  final HtmlGameSession session;
  final int channelId;
  final VoidCallback changed;
  final Map<String, Object?> description;
}
