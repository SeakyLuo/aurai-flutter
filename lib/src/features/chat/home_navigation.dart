import 'package:flutter/material.dart';

import 'chat_controller.dart';
import 'chat_page.dart';

List<Route<dynamic>> initialHomeRoutes(ChatController controller, Widget root) {
  final conversation = controller.activeConversation;
  final restore =
      !controller.startsWithoutConversations &&
      controller.hasRestoredConversation &&
      (conversation.kind == ConversationKind.group || !conversation.isEmpty);
  return [
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/'),
      builder: (_) => root,
    ),
    if (restore || controller.startsWithoutConversations)
      MaterialPageRoute<void>(
        builder: (_) => ChatPage(controller: controller, stacked: true),
      ),
  ];
}

Future<void> openHomeConversation(
  BuildContext context,
  ChatController controller,
  String id, {
  String? messageId,
  bool preservePreviousRoute = false,
}) async {
  await controller.selectConversation(id);
  if (!context.mounted) return;
  final navigator = Navigator.of(context);
  if (!preservePreviousRoute) navigator.popUntil((route) => route.isFirst);
  final route = navigator.push<void>(
    MaterialPageRoute(
      builder: (_) => ChatPage(
        controller: controller,
        stacked: true,
        initialMessageId: messageId,
      ),
    ),
  );
  if (preservePreviousRoute) await route;
}
