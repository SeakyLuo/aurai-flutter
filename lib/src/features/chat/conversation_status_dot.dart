import 'package:flutter/material.dart';
import 'chat_controller.dart';
import 'conversation_list_status.dart';
import 'task_failure_icon.dart';
import '../../storage/development_projects.dart';
import 'project_icon.dart';
import 'settings_appearance.dart';

const unreadDotColor = Colors.red;

class ConversationStatusDot extends StatelessWidget {
  const ConversationStatusDot({super.key, required this.conversation});
  final Conversation conversation;

  static bool hasUnreadCompletion(Conversation conversation) =>
      !conversation.isTask
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
                  color: unreadDotColor,
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
    this.project,
    this.showScheduled = true,
  });
  final Conversation conversation;
  final Widget child;
  final ChatController controller;
  final DevelopmentProject? project;
  final bool showScheduled;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller.scheduledTasks,
    builder: (context, _) => Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (project case final project?)
          Positioned(
            bottom: -3,
            right: -3,
            child: Semantics(
              label: '项目：${project.name}',
              child: Container(
                width: 22,
                height: 22,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  color: settingsFieldColor(context),
                ),
                child: ProjectIcon(
                  icon: project.icon,
                  color: project.iconColor,
                  size: 16,
                ),
              ),
            ),
          ),
        if (ConversationStatusDot.hasUnreadCompletion(conversation))
          Positioned(
            top: -2,
            right: -2,
            child: Semantics(
              label: conversation.isPersonalChat
                  ? '${conversation.unreadMessageCount}条未读消息'
                  : '有新消息',
              child: Container(
                constraints: conversation.isPersonalChat
                    ? const BoxConstraints(minWidth: 20, minHeight: 20)
                    : null,
                width: conversation.isPersonalChat ? null : 12,
                height: conversation.isPersonalChat ? null : 12,
                padding: conversation.isPersonalChat
                    ? const EdgeInsets.symmetric(horizontal: 5, vertical: 1)
                    : null,
                decoration: BoxDecoration(
                  borderRadius: conversation.isPersonalChat
                      ? BorderRadius.circular(12)
                      : null,
                  shape: conversation.isPersonalChat
                      ? BoxShape.rectangle
                      : BoxShape.circle,
                  color: unreadDotColor,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
                child: conversation.isPersonalChat
                    ? Text(
                        conversation.unreadMessageCount > 99
                            ? '99+'
                            : '${conversation.unreadMessageCount}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        if (showScheduled &&
            ConversationListStatus.isScheduled(controller, conversation))
          Positioned(
            bottom: -3,
            right: project == null ? -3 : null,
            left: project == null ? null : -3,
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
