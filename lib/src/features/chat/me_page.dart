import '../../domain/error_message.dart';
import 'package:flutter/material.dart';
import '../../scheduling/tasks_page.dart';
import 'archived_conversations_page.dart';
import 'chat_controller.dart';
import 'conversation_menu_icon.dart';
import 'home_navigation.dart';
import 'personal_info_page.dart';
import 'profile_avatar.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'settings_page.dart';
import 'sidebar_action_icon.dart';

class MePage extends StatelessWidget {
  const MePage({super.key, required this.controller});
  final ChatController controller;

  Future<void> _archive(BuildContext context) async {
    try {
      final id = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => ArchivedConversationsPage(controller: controller),
        ),
      );
      if (context.mounted && id != null)
        await openHomeConversation(context, controller, id);
    } on Object catch (error) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法打开会话，请重试：${errorMessage(error)}')),
        );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const SettingsAppBar(title: '我', onBack: null, root: true),
    body: ListenableBuilder(
      listenable: controller.memory,
      builder: (context, _) {
        final memory = controller.memory;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.only(top: 12, bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PersonalInfoPage(memory: memory),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 20,
                      ),
                      child: Row(
                        children: [
                          ProfileAvatar(
                            style: memory.avatar,
                            name: memory.nickname,
                            size: 72,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  memory.nickname.isEmpty
                                      ? '个人信息'
                                      : memory.nickname,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 23,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  memory.nickname.isEmpty ? '设置头像与昵称' : '个人信息',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          const SettingsIcon(type: SettingsIconType.chevron),
                        ],
                      ),
                    ),
                  ),
                ),
                _entry(
                  context,
                  '定时任务',
                  const SettingsIcon(type: SettingsIconType.tasks),
                  () => openScheduledTasks(context, controller),
                ),
                _entry(
                  context,
                  '已归档会话',
                  ConversationMenuIcon(
                    type: ConversationMenuIconType.archive,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : const Color(0xff222222),
                  ),
                  () => _archive(context),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: SizedBox(
                    height: 8,
                    child: ColoredBox(color: settingsFieldColor(context)),
                  ),
                ),
                _entry(
                  context,
                  '设置',
                  const SidebarActionIcon(type: SidebarActionIconType.settings),
                  () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SettingsPage(
                        controller: controller,
                        preparingGoal: () => false,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Widget _entry(
    BuildContext context,
    String title,
    Widget icon,
    VoidCallback onTap,
  ) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
    leading: icon,
    title: Text(title, style: const TextStyle(fontSize: 16)),
    trailing: const SettingsIcon(type: SettingsIconType.chevron),
    onTap: onTap,
  );
}
