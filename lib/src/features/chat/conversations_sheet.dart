import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../utils/widget_utils.dart';
import 'chat_controller.dart';
import 'conversation_more.dart';
import 'conversation_status_dot.dart';
import 'compose_icon.dart';
import 'sidebar_action_icon.dart';
import 'settings_icon.dart';
import 'glass_surface.dart';
import 'pagination_listener.dart';

enum ConversationAction {
  create,
  select,
  search,
  settings,
  tasks,
  groups,
  createGroup,
}

typedef ConversationSelection = ({
  ConversationAction action,
  String? id,
  String? messageId,
});

class ConversationsDrawer extends StatelessWidget {
  const ConversationsDrawer({
    super.key,
    required this.controller,
    required this.onChoose,
  });
  final ChatController controller;
  final ValueChanged<ConversationSelection> onChoose;

  void _choose(ConversationAction action, [String? id]) =>
      onChoose((action: action, id: id, messageId: null));

  @override
  Widget build(BuildContext context) => Drawer(
    width: math.min(380, MediaQuery.sizeOf(context).width * 0.84),
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(),
    clipBehavior: Clip.antiAlias,
    child: SafeArea(
      child: ListenableBuilder(
        listenable: Listenable.merge([controller, controller.scheduledTasks]),
        builder: (context, _) {
          final taskConversationIds = controller.scheduledTasks.tasks
              .expand(
                (task) => [
                  task['sourceConversationId'],
                  task['conversationId'],
                ],
              )
              .whereType<String>()
              .toSet();
          final conversations = controller.conversations
              .where(
                (conversation) =>
                    conversation.kind == ConversationKind.direct &&
                    !conversation.isEmpty,
              )
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Image.asset(
                          'assets/branding/wordmark_white.png',
                          width: 144,
                          height: 48,
                          fit: BoxFit.contain,
                          color: Theme.of(context).colorScheme.onSurface,
                          colorBlendMode: BlendMode.srcIn,
                          semanticLabel: 'Aurai',
                        ),
                      ),
                    ),
                    RoundAction(
                      icon: Icons.search_rounded,
                      iconWidget: const SidebarActionIcon(
                        type: SidebarActionIconType.search,
                      ),
                      label: '搜索会话',
                      onPressed: () => _choose(ConversationAction.search),
                    ),
                  ],
                ),
              ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: 24, right: 16),
                leading: const SidebarActionIcon(
                  type: SidebarActionIconType.group,
                ),
                title: const Text(
                  '群聊',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                trailing: RoundAction(
                  icon: Icons.add_rounded,
                  iconWidget: const SidebarActionIcon(
                    type: SidebarActionIconType.add,
                  ),
                  label: '新建群聊',
                  onPressed: () => _choose(ConversationAction.createGroup),
                ),
                onTap: () => _choose(ConversationAction.groups),
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: const SettingsIcon(type: SettingsIconType.tasks),
                title: const Text(
                  '任务',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                onTap: () => _choose(ConversationAction.tasks),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(24, 12, 24, 12),
                child: Text(
                  '会话列表',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: PaginationListener(
                        hasMore: controller.hasMoreConversations,
                        loadMore: controller.loadMoreConversations,
                        child: conversations.isEmpty
                            ? const Center(child: Text('还没有会话，点击下方新建会话'))
                            : ListView.builder(
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  0,
                                  10,
                                  88,
                                ),
                                itemCount: conversations.length,
                                itemBuilder: (context, index) {
                                  final conversation = conversations[index];
                                  final selected =
                                      conversation.id ==
                                      controller.activeConversation.id;
                                  return ConversationMore(
                                    key: ValueKey(conversation.id),
                                    controller: controller,
                                    conversation: conversation,
                                    child: Semantics(
                                      selected: selected,
                                      button: true,
                                      child: Material(
                                        color: selected
                                            ? Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.05)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(14),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          onTap: () => _choose(
                                            ConversationAction.select,
                                            conversation.id,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 17,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        conversation.title,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurface,
                                                        ),
                                                      ),
                                                    ),
                                                    ConversationStatusDot(
                                                      conversation:
                                                          conversation,
                                                    ),
                                                    if (conversation
                                                        .isPinned) ...[
                                                      const SizedBox(width: 8),
                                                      Icon(
                                                        Icons.push_pin_rounded,
                                                        size: 16,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                        semanticLabel: '已置顶',
                                                      ),
                                                    ],
                                                    if (!ConversationStatusDot.hasUnreadCompletion(
                                                          conversation,
                                                        ) &&
                                                        (conversation
                                                                .isScheduledTask ||
                                                            taskConversationIds
                                                                .contains(
                                                                  conversation
                                                                      .id,
                                                                ))) ...[
                                                      const SizedBox(width: 8),
                                                      Semantics(
                                                        label: '定时任务',
                                                        child: SizedBox.square(
                                                          dimension: 16,
                                                          child: FittedBox(
                                                            child: SettingsIcon(
                                                              type:
                                                                  SettingsIconType
                                                                      .tasks,
                                                              color: Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurfaceVariant,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                if (conversation.messageCount ==
                                                        0 &&
                                                    conversation
                                                        .draft
                                                        .isNotEmpty) ...[
                                                  const SizedBox(height: 5),
                                                  Text(
                                                    conversation.draft,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 20,
                      child: Row(
                        children: [
                          Expanded(
                            child: WidgetUtils.primaryButton(
                              text: '新建会话',
                              fontSize: 14,
                              height: 40,
                              frosted: true,
                              liquidGlass: true,
                              textColor: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.8),
                              onPressed: () =>
                                  _choose(ConversationAction.create),
                              icon: ComposeIcon(
                                size: 20,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          GlassSurface(
                            radius: 24,
                            child: RoundAction(
                              icon: Icons.settings_outlined,
                              iconWidget: const SidebarActionIcon(
                                type: SidebarActionIconType.settings,
                              ),
                              label: '设置',
                              onPressed: () =>
                                  _choose(ConversationAction.settings),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
