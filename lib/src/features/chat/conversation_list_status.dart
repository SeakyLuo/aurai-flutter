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
  });

  final ChatController controller;
  final Conversation conversation;
  final bool showUnread;

  static bool hasStatus(
    ChatController controller,
    Conversation conversation, {
    bool showUnread = true,
  }) =>
      (conversation.kind != ConversationKind.group &&
          conversation.runState == ChatRunState.failed) ||
      (showUnread && ConversationStatusDot.hasUnreadCompletion(conversation)) ||
      _isScheduled(controller, conversation);

  static bool _isScheduled(
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
      final scheduled = _isScheduled(controller, conversation);
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
          if (showUnread ||
              !ConversationStatusDot.hasUnreadCompletion(conversation))
            ConversationStatusDot(conversation: conversation),
        ],
      );
    },
  );
}
