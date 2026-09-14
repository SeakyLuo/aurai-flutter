import 'package:flutter/material.dart';

import 'chat_controller.dart';
import 'conversation_status_dot.dart';
import 'settings_icon.dart';

class ConversationListStatus extends StatelessWidget {
  const ConversationListStatus({
    super.key,
    required this.controller,
    required this.conversation,
  });

  final ChatController controller;
  final Conversation conversation;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller.scheduledTasks,
    builder: (context, _) {
      final scheduled =
          conversation.isScheduledTask ||
          controller.scheduledTasks.tasks.any(
            (task) =>
                task['sourceConversationId'] == conversation.id ||
                task['conversationId'] == conversation.id,
          );
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (scheduled &&
              !ConversationStatusDot.hasUnreadCompletion(conversation))
            Semantics(
              label: '定时任务',
              child: SizedBox.square(
                dimension: 16,
                child: FittedBox(
                  child: SettingsIcon(
                    type: SettingsIconType.tasks,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ConversationStatusDot(conversation: conversation),
        ],
      );
    },
  );
}
