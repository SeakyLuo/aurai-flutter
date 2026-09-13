import 'package:flutter/material.dart';
import 'chat_controller.dart';
import 'home_navigation.dart';

Future<void> openGroupConversation(
  BuildContext context,
  ChatController controller,
  String id,
) async {
  try {
    await openHomeConversation(context, controller, id);
  } on Object {
    if (context.mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开群聊，请重试')));
  }
}
