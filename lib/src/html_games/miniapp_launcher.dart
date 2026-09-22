import 'dart:io';
import 'package:flutter/material.dart';
import 'html_game_store.dart';
import 'html_game_view.dart';
import 'miniapp_library_store.dart';
import 'miniapp_run_page.dart';

Future<void> openMiniapp(
  BuildContext context,
  MiniappEntry entry,
  HtmlGameStore store,
) async {
  final library = MiniappLibraryStore(store.database);
  if (!Platform.isAndroid) throw StateError('请在 Android 版 Aurai 中打开小程序');
  var id = entry.runtimeId;
  if (!entry.draft && entry.installedId == null) {
    id = await library.install(entry);
  }
  final launcher = entry.draft ? await library.launcher(id) : null;
  late final Widget page;
  if (launcher == null) {
    final game = await library.loadIndependent(id);
    page = MiniappRunPage(game: game, store: store);
  } else {
    final messageId = launcher['message_id'] as String;
    final conversationId = launcher['conversation_id'] as String;
    final card = await store.card(messageId);
    // Validate the original entry before navigating to its existing runtime.
    await store.load(conversationId, messageId);
    page = HtmlGameView(
      card: card,
      messageId: messageId,
      conversationId: conversationId,
      store: store,
      fullscreen: true,
      backLabel: '返回小程序',
    );
  }
  if (!context.mounted) return;
  await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => page));
}
