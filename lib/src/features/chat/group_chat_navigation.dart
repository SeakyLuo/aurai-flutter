import '../../domain/error_message.dart';
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
  } on Object catch (error) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开群聊，请重试：${errorMessage(error)}')),
      );
  }
}
