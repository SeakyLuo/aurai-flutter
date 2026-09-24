import 'package:flutter/material.dart';
import 'chat_controller.dart';
import 'conversation_list_status.dart';
import 'task_failure_icon.dart';

class ConversationStatusDot extends StatelessWidget {
  const ConversationStatusDot({super.key, required this.conversation});
  final Conversation conversation;

  static bool hasUnreadCompletion(Conversation conversation) =>
      conversation.kind == ConversationKind.group
      ? conversation.unreadMessageCount > 0
      : conversation.runState == ChatRunState.idle &&
            conversation.activeRunId != null &&
            conversation.seenRunId != conversation.activeRunId &&
            conversation.pendingGoal == null;

  static bool needsAttention(Conversation conversation) =>
      conversation.kind != ConversationKind.group &&
      (conversation.runState == ChatRunState.failed ||
          conversation.runState == ChatRunState.interrupted);

  @override
  Widget build(BuildContext context) {
    final attention = needsAttention(conversation);
    final completed = hasUnreadCompletion(conversation);
    if (!attention && !completed) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Semantics(
        label: attention
            ? conversation.runState == ChatRunState.interrupted
                  ? '任务已中断'
                  : '任务出错'
            : '有新消息',
        child: attention
            ? const TaskFailureIcon()
            : Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
      ),
    );
  }
}

class ConversationUnreadAvatar extends StatelessWidget {
  const ConversationUnreadAvatar({
    super.key,
    required this.conversation,
    required this.child,
    required this.controller,
  });
  final Conversation conversation;
  final Widget child;
  final ChatController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller.scheduledTasks,
    builder: (context, _) => Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (ConversationStatusDot.hasUnreadCompletion(conversation))
          Positioned(
            top: -2,
            right: -2,
            child: Semantics(
              label: '有新消息',
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primary,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
        if (ConversationListStatus.isScheduled(controller, conversation))
          Positioned(
            bottom: -3,
            right: -3,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
              child: ConversationListStatus(
                controller: controller,
                conversation: conversation,
                showUnread: false,
                showFailure: false,
              ),
            ),
          ),
      ],
    ),
  );
}
