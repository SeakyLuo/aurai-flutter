import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import 'package:flutter/material.dart';
import 'model_settings_sheet.dart';
import 'starred_messages_page.dart';
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
        ScaffoldMessenger.of(context).showGlassSnackBar(
          SnackBar(content: Text('无法打开会话，请重试：${errorMessage(error)}')),
        );
    }
  }

  Future<void> _providers(BuildContext context) async {
    if (controller.addingImages) {
      ScaffoldMessenger.of(
        context,
      ).showGlassSnackBar(const SnackBar(content: Text('正在处理图片，请稍候')));
      return;
    }
    await ModelSettingsSheet.show(
      context,
      controller: controller,
      continueAfterSave: false,
      accountOnly: true,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListenableBuilder(
      listenable: controller.memory,
      builder: (context, _) {
        final memory = controller.memory;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                View.of(context).padding.top /
                        View.of(context).devicePixelRatio +
                    16,
                16,
                MediaQuery.paddingOf(context).bottom + 16,
              ),
              children: [
                Center(
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(26),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PersonalInfoPage(memory: memory),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ProfileAvatar(
                              style: memory.avatar,
                              name: memory.nickname,
                              size: 80,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              memory.nickname.isEmpty
                                  ? '个人信息'
                                  : memory.nickname,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _entry(
                  context,
                  '个人信息',
                  const SettingsIcon(type: SettingsIconType.personalInfo),
                  () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PersonalInfoPage(memory: memory),
                    ),
                  ),
                ),
                _entry(
                  context,
                  '模型供应商',
                  const SettingsIcon(type: SettingsIconType.modelProvider),
                  () => _providers(context),
                ),
                _entry(
                  context,
                  '收藏',
                  const SettingsIcon(type: SettingsIconType.star),
                  () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          StarredMessagesPage(controller: controller),
                    ),
                  ),
                ),
                _entry(
                  context,
                  '已归档',
                  ConversationMenuIcon(
                    type: ConversationMenuIconType.archive,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : const Color(0xff222222),
                  ),
                  () => _archive(context),
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
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: settingsFieldColor(context),
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18),
        minVerticalPadding: 18,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        leading: icon,
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        trailing: const SettingsIcon(type: SettingsIconType.chevron),
        onTap: onTap,
      ),
    ),
  );
}
