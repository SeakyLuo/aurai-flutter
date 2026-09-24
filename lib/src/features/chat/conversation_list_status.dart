import 'package:flutter/material.dart';

import 'chat_controller.dart';
import 'conversation_status_dot.dart';
import 'settings_icon.dart';

class ConversationListStatus extends StatelessWidget {
  const ConversationListStatus({
    super.key,
    required this.controller,
    required this.conversation,
    this.showUnread = true,
    this.showFailure = true,
  });

  final ChatController controller;
  final Conversation conversation;
  final bool showUnread;
  final bool showFailure;

  static bool hasStatus(
    ChatController controller,
    Conversation conversation, {
    bool showUnread = true,
  }) =>
      ConversationStatusDot.needsAttention(conversation) ||
      (showUnread && ConversationStatusDot.hasUnreadCompletion(conversation)) ||
      isScheduled(controller, conversation);

  static bool isScheduled(
    ChatController controller,
    Conversation conversation,
  ) =>
      conversation.isScheduledTask ||
      controller.scheduledTasks.tasks.any(
        (task) =>
            task['sourceConversationId'] == conversation.id ||
            task['conversationId'] == conversation.id,
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller.scheduledTasks,
    builder: (context, _) {
      final scheduled = isScheduled(controller, conversation);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (scheduled &&
              (!showUnread ||
                  !ConversationStatusDot.hasUnreadCompletion(conversation)))
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
          if ((showUnread &&
                  ConversationStatusDot.hasUnreadCompletion(conversation)) ||
              (showFailure &&
                  ConversationStatusDot.needsAttention(conversation)))
            ConversationStatusDot(conversation: conversation),
        ],
      );
    },
  );
}
