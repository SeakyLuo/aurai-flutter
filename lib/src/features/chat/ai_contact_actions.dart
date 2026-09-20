import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import 'package:flutter/material.dart';
import '../../domain/ai_profile.dart';
import 'chat_controller.dart';
import 'home_navigation.dart';
import 'glass_surface.dart';
import 'dialog_action_button.dart';

Future<void> openAiChat(
  BuildContext context,
  ChatController controller,
  AiProfile ai,
) async {
  try {
    final id = await controller.openAiConversation(ai);
    if (context.mounted)
      await openHomeConversation(context, controller, id, resetStack: true);
  } on Object catch (error) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showGlassSnackBar(
        SnackBar(content: Text('无法打开会话，请稍后重试：${errorMessage(error)}')),
      );
  }
}

Future<void> changeAiArchive(
  BuildContext context,
  ChatController controller,
  AiProfile ai,
) async {
  if (!ai.sender.archived) {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: GlassSurface(
          radius: 28,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '归档朋友？',
                  style: TextStyle(
                    fontSize: 17,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '保留聊天记录和已有群聊关系，可在已归档朋友中恢复。',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 20),
                DialogActionButton(
                  text: '归档',
                  role: DialogActionRole.destructive,
                  onPressed: () => Navigator.pop(context, true),
                ),
                const SizedBox(height: 10),
                DialogActionButton(
                  text: '取消',
                  role: DialogActionRole.secondary,
                  onPressed: () => Navigator.pop(context, false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (yes != true) return;
  }
  try {
    if (ai.sender.archived) {
      await controller.groupStore.restoreAi(ai.sender.id);
    } else {
      await controller.groupStore.archiveAi(ai.sender.id);
    }
    if (context.mounted)
      ScaffoldMessenger.of(context).showGlassSnackBar(
        SnackBar(content: Text(ai.sender.archived ? '已恢复朋友' : '已归档朋友')),
      );
  } on Object catch (error) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showGlassSnackBar(
        SnackBar(content: Text('操作失败，请重试：${errorMessage(error)}')),
      );
  }
}
