import 'package:flutter/material.dart';

import '../../providers/model_catalog.dart';
import 'capability_page.dart';
import 'chat_controller.dart';
import 'model_settings_sheet.dart';
import 'settings_icon.dart';
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('设置'),
      leading: IconButton(
        tooltip: '返回',
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.maybePop(context),
      ),
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListenableBuilder(
            listenable: Listenable.merge([
              controller,
              AppearanceSettings.instance,
            ]),
            builder: (context, _) => ListTileTheme(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.dark_mode_outlined,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    title: const Text('夜间模式'),
                    subtitle: Text(AppearanceSettings.instance.label),
                    trailing: const SettingsIcon(
                      type: SettingsIconType.chevron,
                    ),
                    onTap: () => _chooseAppearance(context),
                  ),
                  ListTile(
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
                  ListTile(
                    leading: const SettingsIcon(type: SettingsIconType.device),
                    title: const Text('设备能力'),
                    trailing: const SettingsIcon(
                      type: SettingsIconType.chevron,
                    ),
                    onTap: () => CapabilityPage.show(context, controller),
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
