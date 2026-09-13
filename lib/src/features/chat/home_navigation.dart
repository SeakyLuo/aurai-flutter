import 'package:flutter/material.dart';

import 'ai_conversations_page.dart';
import 'chat_controller.dart';
import 'chat_page.dart';

List<Route<dynamic>> initialHomeRoutes(ChatController controller, Widget root) {
  final conversation = controller.activeConversation;
  final restore =
      !controller.startsWithoutConversations &&
      controller.hasRestoredConversation &&
      (conversation.kind == ConversationKind.group || !conversation.isEmpty);
  final ai = controller.activeAi;
  return [
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/'),
      builder: (_) => root,
    ),
    if (restore && ai != null)
      MaterialPageRoute<void>(
        builder: (_) =>
            AiConversationsPage(controller: controller, profile: ai),
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
}) async {
  await controller.selectConversation(id);
  final conversation = controller.activeConversation;
  final ai = conversation.kind == ConversationKind.direct
      ? await controller.groupStore.loadAi(conversation.defaultSenderId)
      : null;
  if (!context.mounted) return;
  final navigator = Navigator.of(context);
  navigator.popUntil((route) => route.isFirst);
  if (ai != null) {
    navigator.push<void>(
      MaterialPageRoute(
        builder: (_) =>
            AiConversationsPage(controller: controller, profile: ai),
      ),
    );
  }
  navigator.push<void>(
    MaterialPageRoute(
      builder: (_) => ChatPage(
        controller: controller,
        stacked: true,
        initialMessageId: messageId,
      ),
    ),
  );
}
