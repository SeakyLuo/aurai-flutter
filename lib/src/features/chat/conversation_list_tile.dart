import 'package:flutter/material.dart';
import 'chat_controller.dart';
import 'conversation_status_dot.dart';
import 'conversation_list_status.dart';
import 'conversation_preview_text.dart';
import 'message_time.dart';
import '../../storage/development_projects.dart';

class ConversationListTile extends StatelessWidget {
  const ConversationListTile({
    super.key,
    required this.controller,
    required this.conversation,
    required this.avatar,
    required this.onTap,
    this.project,
    this.displayName,
  });

  final ChatController controller;
  final Conversation conversation;
  final Widget avatar;
  final VoidCallback onTap;
  final DevelopmentProject? project;
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    final item = conversation;
    final group = item.kind == ConversationKind.group;
    return Material(
      color: item.isPinned
          ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.035)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        horizontalTitleGap: 12,
        leading: ConversationUnreadAvatar(
          controller: controller,
          conversation: item,
          project: project,
          showScheduled: false,
          child: avatar,
        ),
        title: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      displayName ?? item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  ListenableBuilder(
                    listenable: controller.scheduledTasks,
                    builder: (context, _) =>
                        ConversationListStatus.isScheduled(controller, item)
                        ? Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: ConversationListStatus(
                              controller: controller,
                              conversation: item,
                              showUnread: false,
                              showFailure: false,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            if (item.lastMessageAt != null) ...[
              const SizedBox(width: 8),
              Text(
                conversationMessageTime(item.lastMessageAt!),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        subtitle: ConversationPreviewText(
          prefix: group && item.unreadMessageCount > 0
              ? '[${item.unreadMessageCount}条] '
              : '',
          showFailure: true,
          showRunning: item.isTask,
          conversation: item,
          emptyText: item.isTask ? '开始任务' : '开始聊天',
        ),
        onTap: onTap,
      ),
    );
  }
}
