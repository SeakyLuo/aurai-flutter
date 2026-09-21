import 'package:flutter/material.dart';
import 'chat_controller.dart';
import 'conversation_status_dot.dart';
import 'conversation_preview_text.dart';
import 'message_time.dart';

class ConversationListTile extends StatelessWidget {
  const ConversationListTile({
    super.key,
    required this.controller,
    required this.conversation,
    required this.avatar,
    required this.onTap,
  });

  final ChatController controller;
  final Conversation conversation;
  final Widget avatar;
  final VoidCallback onTap;

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
          child: avatar,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16),
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
          conversation: item,
          emptyText: '开始聊天',
        ),
        onTap: onTap,
      ),
    );
  }
}
