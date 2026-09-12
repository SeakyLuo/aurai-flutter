import '../../skills/skills_page.dart';
import 'package:flutter/material.dart';
import '../../memory/memory_summary_page.dart';

import '../../providers/model_catalog.dart';
import 'capability_page.dart';
import 'archived_conversations_page.dart';
import 'conversation_menu_icon.dart';
import 'chat_controller.dart';
import 'model_settings_sheet.dart';
import 'personalization_page.dart';
import 'personal_info_page.dart';
import 'settings_icon.dart';
import 'settings_appearance.dart';
import 'choice_sheet.dart';
import '../../app/appearance_settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.controller,
    required this.preparingGoal,
  });

  final ChatController controller;
  final bool Function() preparingGoal;

  Future<void> _openModel(BuildContext context) async {
    if (controller.addingImages) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('正在处理图片，请稍候')));
      return;
    }
    if (controller.hasRunningTask || preparingGoal()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先停止当前任务，再修改模型')));
      return;
    }
    await ModelSettingsSheet.show(
      context,
      controller: controller,
      continueAfterSave: false,
    );
  }

  Future<void> _chooseAppearance(BuildContext context) async {
    final settings = AppearanceSettings.instance;
    final mode = await showChoiceSheet<ThemeMode>(
      context,
      title: '夜间模式',
      selected: settings.mode,
      choices: const [
        (value: ThemeMode.system, label: '跟随系统'),
        (value: ThemeMode.light, label: '关闭'),
        (value: ThemeMode.dark, label: '开启'),
      ],
    );
    if (mode == null || mode == settings.mode) return;
    try {
      await settings.setMode(mode);
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法保存夜间模式，请重试')));
    }
  }

  Future<void> _openSkills(BuildContext context) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => SkillsPage(store: controller.skills)),
    );
  }

  Future<void> _openArchive(BuildContext context) async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ArchivedConversationsPage(controller: controller),
      ),
    );
    if (context.mounted && id != null) Navigator.pop(context, id);
  }

  Future<void> _openNotifications(BuildContext context) async {
    try {
      await controller.openNotificationSettings();
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开通知设置，请重试')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: SettingsAppBar(
      title: '设置',
      onBack: () => Navigator.maybePop(context),
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListenableBuilder(
            listenable: Listenable.merge([
              controller,
              controller.memory,
              AppearanceSettings.instance,
            ]),
            builder: (context, _) => ListTileTheme(
              data: ListTileThemeData(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                tileColor: settingsFieldColor(context),
                titleTextStyle: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                subtitleTextStyle: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                minVerticalPadding: 18,
                contentPadding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                children: [
                  Material(
                    color: settingsFieldColor(context),
                    borderRadius: BorderRadius.circular(26),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: const SettingsIcon(
                        type: SettingsIconType.personalInfo,
                      ),
                      title: const Text('个人信息'),
                      subtitle: const Text('昵称、职业与更多信息'),
                      trailing: const SettingsIcon(
                        type: SettingsIconType.chevron,
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              PersonalInfoPage(memory: controller.memory),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Material(
                    color: settingsFieldColor(context),
                    borderRadius: BorderRadius.circular(26),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: const SettingsIcon(
                        type: SettingsIconType.personalization,
                      ),
                      title: const Text('个性化'),
                      subtitle: const Text('自定义指令与系统提示词'),
                      trailing: const SettingsIcon(
                        type: SettingsIconType.chevron,
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              PersonalizationPage(controller: controller),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Material(
                    color: settingsFieldColor(context),
                    borderRadius: BorderRadius.circular(26),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: const SettingsIcon(
                        type: SettingsIconType.memory,
                      ),
                      title: const Text('记忆'),
                      subtitle: const Text('查看和管理跨会话记忆'),
                      trailing: const SettingsIcon(
                        type: SettingsIconType.chevron,
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              MemorySummaryPage(memory: controller.memory),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Material(
                    color: settingsFieldColor(context),
                    borderRadius: BorderRadius.circular(26),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: const SettingsIcon(type: SettingsIconType.model),
                      title: const Text('模型设置'),
                      subtitle: Text(
                        controller.needsConfiguration
                            ? '连接模型'
                            : modelDisplayName(controller.config.model),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const SettingsIcon(
                        type: SettingsIconType.chevron,
                      ),
                      onTap: () => _openModel(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Material(
                    color: settingsFieldColor(context),
                    borderRadius: BorderRadius.circular(26),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: const SettingsIcon(
                        type: SettingsIconType.skills,
                      ),
                      title: const Text('技能'),
                      subtitle: const Text('管理 Aurai 保存的操作方法'),
                      trailing: const SettingsIcon(
                        type: SettingsIconType.chevron,
                      ),
                      onTap: () => _openSkills(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Material(
                    color: settingsFieldColor(context),
                    borderRadius: BorderRadius.circular(26),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: const SettingsIcon(
                        type: SettingsIconType.device,
                      ),
                      title: const Text('设备能力'),
                      trailing: const SettingsIcon(
                        type: SettingsIconType.chevron,
                      ),
                      onTap: () => CapabilityPage.show(context, controller),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Material(
                    color: settingsFieldColor(context),
                    borderRadius: BorderRadius.circular(26),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: const SettingsIcon(
                        type: SettingsIconType.appearance,
                      ),
                      title: const Text('夜间模式'),
                      subtitle: Text(AppearanceSettings.instance.label),
                      trailing: const SettingsIcon(
                        type: SettingsIconType.chevron,
                      ),
                      onTap: () => _chooseAppearance(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Material(
                    color: settingsFieldColor(context),
                    borderRadius: BorderRadius.circular(26),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: const SettingsIcon(
                        type: SettingsIconType.notifications,
                      ),
                      title: const Text('通知'),
                      subtitle: const Text('在系统设置中开启或关闭'),
                      trailing: const SettingsIcon(
                        type: SettingsIconType.chevron,
                      ),
                      onTap: () => _openNotifications(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Material(
                    color: settingsFieldColor(context),
                    borderRadius: BorderRadius.circular(26),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: ConversationMenuIcon(
                        type: ConversationMenuIconType.archive,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : const Color(0xff222222),
                      ),
                      title: const Text('已归档会话'),
                      trailing: const SettingsIcon(
                        type: SettingsIconType.chevron,
                      ),
                      onTap: () => _openArchive(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
