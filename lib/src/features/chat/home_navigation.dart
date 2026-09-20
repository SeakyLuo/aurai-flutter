import 'package:flutter/material.dart';

import 'chat_controller.dart';
import 'chat_page.dart';
import 'home_page.dart';
import 'ai_contacts_page.dart';

List<Route<dynamic>> initialHomeRoutes(ChatController controller, Widget root) {
  final conversation = controller.activeConversation;
  final restore =
      !controller.startsWithoutConversations &&
      controller.hasRestoredConversation &&
      controller.navigationState.detailVisible &&
      (conversation.kind == ConversationKind.group || !conversation.isEmpty);
  return [
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/'),
      builder: (_) => root,
    ),
    if (controller.startsWithoutConversations)
      MaterialPageRoute<void>(
        builder: (_) =>
            AiContactsPage(controller: controller, selectForConversation: true),
      )
    else if (restore)
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
  bool waitForClose = false,
  bool resetStack = false,
}) async {
  await controller.selectConversation(id);
  if (!context.mounted) return;
  final navigator = Navigator.of(context);
  final page = MaterialPageRoute<void>(
    builder: (_) => ChatPage(
      controller: controller,
      stacked: true,
      initialMessageId: messageId,
    ),
  );
  if (resetStack) HomePage.showConversations();
  final route = resetStack
      ? navigator.pushAndRemoveUntil<void>(page, (route) => route.isFirst)
      : navigator.push<void>(page);
  if (waitForClose) await route;
}
