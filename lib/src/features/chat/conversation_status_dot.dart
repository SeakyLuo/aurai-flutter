import 'package:flutter/material.dart';
import 'conversation.dart';
import 'task_failure_icon.dart';

class ConversationStatusDot extends StatelessWidget {
  const ConversationStatusDot({super.key, required this.conversation});
  final Conversation conversation;

  static bool hasUnreadCompletion(Conversation conversation) =>
      conversation.runState == ChatRunState.idle &&
      conversation.activeRunId != null &&
      conversation.seenRunId != conversation.activeRunId &&
      conversation.pendingGoal == null;

  @override
  Widget build(BuildContext context) {
    final failed =
        conversation.kind != ConversationKind.group &&
        conversation.runState == ChatRunState.failed;
    final completed = hasUnreadCompletion(conversation);
    if (!failed && !completed) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Semantics(
        label: failed ? '任务出错' : '有新消息',
        child: failed
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
