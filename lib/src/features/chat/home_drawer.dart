import '../../app/glass_notice.dart';
import 'chat_header_background.dart';
import '../../domain/error_message.dart';
import 'conversation_more.dart';
import 'conversation_icon.dart';
import 'conversation_preview_text.dart';
import 'conversation_status_dot.dart';
import 'home_navigation.dart';
import 'pagination_listener.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../scheduling/tasks_page.dart';
import 'ai_contacts_page.dart';
import 'chat_controller.dart';
import 'conversation_search_page.dart';
import 'personal_info_page.dart';
import 'profile_avatar.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'settings_page.dart';
import 'sidebar_action_icon.dart';

class HomeDrawer extends StatefulWidget {
  const HomeDrawer({super.key, required this.controller});
  final ChatController controller;

  @override
  State<HomeDrawer> createState() => _HomeDrawerState();
}

class _HomeDrawerState extends State<HomeDrawer> {
  final _scroll = ScrollController();
  ChatController get controller => widget.controller;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToTop() => _scroll.animateTo(
    0,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOutCubic,
  );

  void _open(BuildContext context, Widget page) {
    final navigator = Navigator.of(context);
    Scaffold.of(context).closeDrawer();
    navigator.push<void>(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) => Drawer(
    width: math.min(380, MediaQuery.sizeOf(context).width * .84),
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(),
    clipBehavior: Clip.antiAlias,
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Semantics(
                      button: true,
                      label: 'Aurai，回到顶部',
                      excludeSemantics: true,
                      child: InkWell(
                        onTap: _scrollToTop,
                        borderRadius: BorderRadius.circular(12),
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
                  ),
                ),
                SettingsGlassAction(
                  label: '搜索会话',
                  icon: Icons.search_rounded,
                  iconWidget: const SidebarActionIcon(
                    type: SidebarActionIconType.search,
                  ),
                  onPressed: () => _open(
                    context,
                    ConversationSearchPage(
                      controller: controller,
                      preparingGoal: () => false,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) {
                    final conversations = controller.conversations
                        .where(
                          (item) =>
                              item.kind == ConversationKind.group ||
                              !item.isEmpty,
                        )
                        .toList();
                    return PaginationListener(
                      hasMore: controller.hasMoreConversations,
                      loadMore: controller.loadMoreConversations,
                      child: ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 72),
                        itemCount: conversations.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0)
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _entry(
                                  '通讯录',
                                  const SettingsIcon(
                                    type: SettingsIconType.contacts,
                                  ),
                                  () => _open(
                                    context,
                                    AiContactsPage(controller: controller),
                                  ),
                                ),
                                _entry(
                                  '定时任务',
                                  const SettingsIcon(
                                    type: SettingsIconType.tasks,
                                  ),
                                  () {
                                    Scaffold.of(context).closeDrawer();
                                    openScheduledTasks(context, controller);
                                  },
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    12,
                                    12,
                                    8,
                                  ),
                                  child: Text(
                                    '会话列表',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                if (conversations.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Text('暂无会话'),
                                  ),
                              ],
                            );
                          return _conversation(
                            context,
                            conversations[index - 1],
                          );
                        },
                      ),
                    );
                  },
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: RotatedBox(
                            quarterTurns: 2,
                            child: ChatHeaderBackground(surfaceOpacity: .8),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: ListenableBuilder(
                                listenable: controller.memory,
                                builder: (context, _) => InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => _open(
                                    context,
                                    PersonalInfoPage(memory: controller.memory),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        ProfileAvatar(
                                          style: controller.memory.avatar,
                                          name: controller.memory.nickname,
                                          size: 36,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            controller.memory.nickname.isEmpty
                                                ? '设置昵称'
                                                : controller.memory.nickname,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SettingsGlassAction(
                              label: '设置',
                              icon: Icons.settings_outlined,
                              iconWidget: const SidebarActionIcon(
                                type: SidebarActionIconType.settings,
                              ),
                              onPressed: () => _open(
                                context,
                                SettingsPage(
                                  controller: controller,
                                  preparingGoal: () => false,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _conversation(BuildContext context, Conversation item) {
    final selected =
        controller.isConversationDetailVisible &&
        item.id == controller.activeConversation.id;
    return ConversationMore(
      key: ValueKey(item.id),
      controller: controller,
      conversation: item,
      child: Material(
        color: selected
            ? Theme.of(context).colorScheme.onSurface.withValues(alpha: .05)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          selected: selected,
          selectedColor: Theme.of(context).colorScheme.onSurface,
          minTileHeight: 48,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: item.kind == ConversationKind.group
              ? SidebarActionIcon(
                  type: SidebarActionIconType.group,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )
              : const ConversationIcon(),
          title: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16),
          ),
          subtitle: item.questionPreview == null
              ? null
              : ConversationPreviewText(conversation: item),
          trailing: ConversationStatusDot(conversation: item),
          onTap: () async {
            final navigator = Navigator.of(context);
            final messenger = ScaffoldMessenger.of(context);
            Scaffold.of(context).closeDrawer();
            try {
              await openHomeConversation(
                navigator.context,
                controller,
                item.id,
              );
            } on Object catch (error) {
              if (messenger.mounted)
                messenger.showGlassSnackBar(
                  SnackBar(content: Text('无法打开会话，请重试：${errorMessage(error)}')),
                );
            }
          },
        ),
      ),
    );
  }

  Widget _entry(String title, Widget icon, VoidCallback onTap) => ListTile(
    minTileHeight: 48,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    leading: icon,
    title: Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
    ),
    onTap: onTap,
  );
}
