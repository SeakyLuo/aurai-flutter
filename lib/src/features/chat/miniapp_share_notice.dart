import 'package:flutter/material.dart';

import '../../app/glass_notice.dart';
import '../../app/ui_action.dart';
import 'chat_controller.dart';
import 'home_navigation.dart';

void showMiniappShareNotice(
  BuildContext context,
  ChatController controller,
  String conversationId, {
  String text = '已分享小程序',
}) {
  final navigationContext = Navigator.of(context).context;
  ScaffoldMessenger.of(context).showGlassSnackBar(
    SnackBar(
      content: Text(text),
      persist: false,
      action: SnackBarAction(
        label: '进入聊天',
        onPressed: () => runUiAction(
          navigationContext,
          () => openHomeConversation(
            navigationContext,
            controller,
            conversationId,
            resetStack: true,
          ),
        ),
      ),
    ),
  );
}
