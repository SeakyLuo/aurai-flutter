import 'package:flutter/material.dart';

import '../../html_games/miniapp_library_page.dart';
import '../../html_games/miniapp_library_store.dart';
import '../../html_games/miniapp_template.dart';
import 'chat_controller.dart';

Future<bool> sendMiniappMessage(
  BuildContext context,
  ChatController controller,
) async {
  final target = controller.activeConversation;
  final entry = await Navigator.push<MiniappEntry>(
    context,
    MaterialPageRoute(
      builder: (_) =>
          MiniappLibraryPage(controller: controller, pickingMessage: true),
    ),
  );
  if (entry == null) return false;
  final template = await MiniappTemplate.load(
    controller.htmlStore.database,
    entry,
  );
  await controller.sendMiniappTemplate(target.id, template, '');
  return true;
}
