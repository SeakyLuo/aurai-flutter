import 'package:flutter/material.dart';
import 'dart:convert';
import '../domain/interactive_message.dart';
import 'html_view.dart';

import '../app/glass_notice.dart';
import '../domain/agent_models.dart';
import '../domain/error_message.dart';
import '../domain/message_sender.dart';
import '../features/chat/image_action_scope.dart';
import '../features/chat/chat_controller.dart';
import '../features/chat/image_forward_page.dart';
import '../features/chat/miniapp_share_notice.dart';
import '../domain/miniapp_share.dart';
import 'miniapp_launcher.dart';
import 'miniapp_library_store.dart';

String _markdownText(String text) => text.replaceAllMapped(
  RegExp(r'[\\`*_{}\[\]()<>#!|]'),
  (match) => '\\${match[0]}',
);

AgentMessage miniappForwardMessage(MiniappEntry entry) {
  final share = MiniappShare.fromEntry(entry);
  return AgentMessage(
    id: newMessageId(),
    role: AgentMessageRole.user,
    senderId: MessageSender.localUser.id,
    text:
        '[小程序 · ${_markdownText(share.title)}](${share.uri})'
        '${entry.description.isEmpty ? '' : '\n\n${_markdownText(entry.description)}'}',
    miniappShare: share,
    createdAt: DateTime.now(),
  );
}

Future<void> forwardMiniapp(BuildContext context, MiniappEntry entry) async {
  final controller = ImageActionScope.of(context);
  final message = miniappForwardMessage(entry);
  late String targetConversationId;
  final sent = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => ImageForwardPage.message(
        pageTitle: '分享小程序',
        controller: controller,
        message: message,
        onSent: (target) => targetConversationId = target.id,
      ),
    ),
  );
  if (context.mounted && sent == true) {
    showMiniappShareNotice(context, controller, targetConversationId);
  }
}

Future<void> openMiniappLink(BuildContext context, Uri uri) async {
  try {
    final controller = ImageActionScope.of(context);
    if (uri.pathSegments.length == 2 && uri.pathSegments.first == 'message') {
      final id = uri.pathSegments.last;
      final rows = await controller.htmlStore.database.query(
        'messages',
        columns: ['conversation_id', 'interactive_json'],
        where: 'id = ? AND kind = ?',
        whereArgs: [id, 'html_game'],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('小程序消息已删除或撤回');
      if (rows.single['interactive_json'] case final String raw) {
        InteractiveMessage.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        ).requireViewer(MessageSender.localUser.id);
      }
      final card = await controller.htmlStore.card(id);
      if (!context.mounted) return;
      await HtmlView(
        card: card,
        messageId: id,
        conversationId: rows.single['conversation_id'] as String,
        store: controller.htmlStore,
      ).openFullscreen(context);
      return;
    }
    if (uri.pathSegments.length != 2 ||
        !MiniappKind.values.any(
          (kind) => kind.name == uri.pathSegments.first,
        )) {
      throw StateError('小程序链接无效');
    }
    final library = MiniappLibraryStore(controller.htmlStore.database);
    final id = uri.pathSegments[1];
    final builtins = await library.bundled();
    final builtin = builtins.where((entry) => entry.id == id).firstOrNull;
    final kind = MiniappKind.values.byName(uri.pathSegments.first);
    final entry =
        builtin ??
        (kind == MiniappKind.published
            ? await library.entryForPublication(id)
            : await library.entryForApp(id));
    if (!context.mounted) return;
    await openMiniapp(context, entry, controller.htmlStore);
  } on Object catch (error) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showToast(
        SnackBar(content: Text(errorMessage(error))),
        kind: ToastKind.error,
      );
  }
}
