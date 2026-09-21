import '../../app/glass_notice.dart';
import '../../app/language_settings.dart';
import 'default_models_page.dart';
import '../../domain/error_message.dart';
import 'data_management_page.dart';
import 'tools_page.dart';
import 'package:flutter/material.dart';

import '../../providers/model_catalog.dart';
import 'capability_page.dart';
import 'chat_controller.dart';
import 'model_settings_sheet.dart';
import 'settings_icon.dart';
import 'settings_appearance.dart';
import 'choice_sheet.dart';
import '../../app/appearance_settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.controller,
    required this.preparingGoal,
    this.root = false,
  });

  final bool root;
  final ChatController controller;
  final bool Function() preparingGoal;

  Future<void> _openModel(BuildContext context) async {
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

  Future<void> _chooseLanguage(BuildContext context) async {
    final settings = LanguageSettings.instance;
    final language = await showChoiceSheet<PreferredLanguage>(
      context,
      title: '偏好语言',
      selected: settings.language,
      choices: [
        for (final language in PreferredLanguage.values)
          (value: language, label: language.label),
      ],
    );
    if (language == null || language == settings.language) return;
    try {
      await settings.setLanguage(language);
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showGlassSnackBar(
          SnackBar(content: Text('无法保存偏好语言：${errorMessage(error)}')),
        );
      }
    }
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
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showGlassSnackBar(
        SnackBar(content: Text('无法保存夜间模式，请重试：${errorMessage(error)}')),
      );
    }
  }

  Future<void> _openNotifications(BuildContext context) async {
    try {
      await controller.openNotificationSettings();
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showGlassSnackBar(
        SnackBar(content: Text('无法打开通知设置，请重试：${errorMessage(error)}')),
      );
    }
  }

  Future<void> _openBackground(BuildContext context) async {
    try {
      await controller.openBatterySettings();
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showGlassSnackBar(
        SnackBar(content: Text('无法打开后台运行设置：${errorMessage(error)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: SettingsAppBar(
      title: '设置',
      gradientBackground: true,
      root: root,
      onBack: () => Navigator.maybePop(context),
    ),
    body: SafeArea(
      top: false,
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListenableBuilder(
            listenable: Listenable.merge([
              controller,
              controller.memory,
              AppearanceSettings.instance,
              LanguageSettings.instance,
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
                padding: EdgeInsets.fromLTRB(
                  16,
                  View.of(context).padding.top /
                          View.of(context).devicePixelRatio +
                      76 +
                      16,
                  16,
                  MediaQuery.paddingOf(context).bottom + 16,
                ),
                children: [
                  Material(
                    color: settingsFieldColor(context),
                    borderRadius: BorderRadius.circular(26),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: const SettingsIcon(
                        type: SettingsIconType.modelProvider,
                      ),
                      title: const Text('模型供应商'),
                      subtitle: Text(
                        '已配置 ${controller.modelSettings.profiles.values.where((profile) => profile.isConfigured).length} 个供应商',
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
                        type: SettingsIconType.modelSettings,
                      ),
                      title: const Text('模型设置'),
                      subtitle: Text(
                        controller.modelSettings.activeConfig.isConfigured
                            ? modelDisplayName(
                                controller.modelSettings.activeConfig.model,
                              )
                            : '未设置',
                      ),
                      trailing: const SettingsIcon(
                        type: SettingsIconType.chevron,
                      ),
                      onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              DefaultModelsPage(controller: controller),
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
                      leading: const SettingsIcon(type: SettingsIconType.tools),
                      title: const Text('工具'),
                      subtitle: const Text('查看工具与管理授权'),
                      trailing: const SettingsIcon(
                        type: SettingsIconType.chevron,
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ToolsPage(controller: controller),
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
                        type: SettingsIconType.device,
                      ),
                      title: const Text('设备能力'),
                      subtitle: Text(
                        '共 ${CapabilityPage.itemCount(controller)} 项设备能力',
                      ),
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
                        type: SettingsIconType.language,
                      ),
                      title: const Text('偏好语言'),
                      subtitle: Text(LanguageSettings.instance.language.label),
                      trailing: const SettingsIcon(
                        type: SettingsIconType.chevron,
                      ),
                      onTap: () => _chooseLanguage(context),
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
                      leading: const SettingsIcon(
                        type: SettingsIconType.device,
                      ),
                      title: const Text('后台运行'),
                      subtitle: const Text('允许息屏后继续回复，减少省电限制'),
                      trailing: const SettingsIcon(
                        type: SettingsIconType.chevron,
                      ),
                      onTap: () => _openBackground(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Material(
                    color: settingsFieldColor(context),
                    borderRadius: BorderRadius.circular(26),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: const SettingsIcon(type: SettingsIconType.data),
                      title: const Text('数据管理'),
                      subtitle: const Text('备份、恢复与缓存清理'),
                      trailing: const SettingsIcon(
                        type: SettingsIconType.chevron,
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              DataManagementPage(controller: controller),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Image.asset(
                        'assets/branding/wordmark_white.png',
                        width: 144,
                        height: 48,
                        fit: BoxFit.contain,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        colorBlendMode: BlendMode.srcIn,
                        semanticLabel: 'AURAI',
                      ),
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
