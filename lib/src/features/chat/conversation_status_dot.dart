import 'package:flutter/material.dart';
import 'conversation.dart';

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
    final failed = conversation.runState == ChatRunState.failed;
    final completed = hasUnreadCompletion(conversation);
    if (!failed && !completed) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Semantics(
        label: failed ? '任务出错' : '任务已完成',
        child: Container(
          width: failed ? 16 : 8,
          height: failed ? 16 : 8,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: failed
                ? Theme.of(context).colorScheme.errorContainer
                : Theme.of(context).colorScheme.primary,
            border: failed
                ? Border.all(color: Theme.of(context).colorScheme.error)
                : null,
          ),
          child: failed
              ? Text(
                  '!',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.error,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
