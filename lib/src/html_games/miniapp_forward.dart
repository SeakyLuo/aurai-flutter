import 'package:flutter/material.dart';

import '../app/glass_notice.dart';
import '../domain/agent_models.dart';
import '../domain/error_message.dart';
import '../domain/message_sender.dart';
import '../features/chat/image_action_scope.dart';
import '../features/chat/chat_controller.dart';
import '../features/chat/image_forward_page.dart';
import 'miniapp_detail_page.dart';
import 'miniapp_library_store.dart';

String _markdownText(String text) => text.replaceAllMapped(
  RegExp(r'[\\`*_{}\[\]()<>#!|]'),
  (match) => '\\${match[0]}',
);

AgentMessage miniappForwardMessage(MiniappEntry entry) {
  final uri = Uri(
    scheme: 'aurai',
    host: 'miniapp',
    pathSegments: [entry.kind.name, entry.id],
  );
  return AgentMessage(
    id: newMessageId(),
    role: AgentMessageRole.user,
    senderId: MessageSender.localUser.id,
    text:
        '[小程序 · ${_markdownText(entry.title)}]($uri)'
        '${entry.description.isEmpty ? '' : '\n\n${_markdownText(entry.description)}'}',
    createdAt: DateTime.now(),
  );
}

Future<void> forwardMiniapp(BuildContext context, MiniappEntry entry) async {
  final controller = ImageActionScope.of(context);
  final message = miniappForwardMessage(entry);
  final sent = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) =>
          ImageForwardPage.message(controller: controller, message: message),
    ),
  );
  if (context.mounted && sent == true) {
    ScaffoldMessenger.of(
      context,
    ).showGlassSnackBar(const SnackBar(content: Text('已转发小程序')));
  }
}

Future<void> openMiniappLink(BuildContext context, Uri uri) async {
  try {
    if (uri.pathSegments.length != 2 ||
        !MiniappKind.values.any(
          (kind) => kind.name == uri.pathSegments.first,
        )) {
      throw StateError('小程序链接无效');
    }
    final controller = ImageActionScope.of(context);
    final library = MiniappLibraryStore(controller.htmlGames.database);
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
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MiniappDetailPage(entry: entry, store: controller.htmlGames),
      ),
    );
  } on Object catch (error) {
    if (context.mounted)
      ScaffoldMessenger.of(
        context,
      ).showGlassSnackBar(SnackBar(content: Text(errorMessage(error))));
  }
}
