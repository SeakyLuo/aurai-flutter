import 'dart:io';
import 'package:flutter/material.dart';
import 'html_store.dart';
import 'miniapp_library_store.dart';
import 'miniapp_task_host.dart';

Future<void> openMiniapp(
  BuildContext context,
  MiniappEntry entry,
  HtmlStore store, {
  VoidCallback? onReady,
}) async {
  final library = MiniappLibraryStore(store.database);
  if (!Platform.isAndroid) throw StateError('请在 Android 版 Aurai 中打开小程序');
  final current = entry.kind == MiniappKind.installed
      ? await library.entryForApp(entry.runtimeId)
      : await library.refresh(entry);
  var id = current.runtimeId;
  if (!current.draft) {
    if (current.listed) {
      id = await library.install(current);
    } else if (current.installedId == null) {
      throw StateError('此小程序已撤下');
    }
  }
  final launcher = current.draft ? await library.launcher(id) : null;
  if (!context.mounted) return;
  onReady?.call();
  if (launcher == null) {
    await MiniappTaskHost.openApp(title: current.title, appId: id);
  } else {
    final messageId = launcher['message_id'] as String;
    final conversationId = launcher['conversation_id'] as String;
    // Validate the original entry before navigating to its existing runtime.
    await store.load(conversationId, messageId);
    await MiniappTaskHost.openMessage(
      title: current.title,
      messageId: messageId,
      conversationId: conversationId,
    );
  }
}
