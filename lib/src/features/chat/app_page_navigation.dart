import 'provider_key_dialog.dart';
import 'image_generation_settings_page.dart';
import 'music_generation_settings_page.dart';
import 'package:flutter/material.dart';
import '../../skills/skills_page.dart';
import '../../scheduling/tasks_page.dart';
import 'ai_contact_page.dart';
import 'chat_controller.dart';
import 'home_navigation.dart';
import 'settings_page.dart';
import 'ai_model_page.dart';
import 'model_settings_sheet.dart';
import '../../domain/model_provider.dart';

Future<void> navigateAppPage(
  BuildContext context,
  ChatController controller,
  Map<String, Object?> args,
) async {
  if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
    throw StateError('请先回到 Aurai，再打开页面');
  }
  if (args['page'] == 'providerKey') {
    final cancelled = args['cancelled'] as ValueNotifier<bool>;
    if (cancelled.value) return;
    args['saved'] =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => ProviderKeyDialog(
            controller: controller,
            service: ModelService.byName(args['service'] as String),
            baseUrl: args['baseUrl'] as String,
            cancelled: cancelled,
          ),
        ) ??
        false;
    return;
  }
  if (args['page'] == 'conversation') {
    await openHomeConversation(
      context,
      controller,
      args['conversationId'] as String,
      messageId: args['messageId'] as String?,
    );
    return;
  }
  if (args['page'] == 'providerConfiguration') {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ModelSettingsSheet(
          controller: controller,
          continueAfterSave: false,
          accountOnly: true,
          initialService: ModelService.byName(args['service'] as String),
        ),
      ),
    );
    return;
  }
  if (args['page'] == 'modelConfiguration') {
    final profile = await controller.groupStore.loadAi(
      args['senderId'] as String,
    );
    if (!context.mounted) throw StateError('页面已关闭');
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AiModelPage(controller: controller, profile: profile),
      ),
    );
    return;
  }
  final page = switch (args['page']) {
    'imageGeneration' => ImageGenerationSettingsPage(controller: controller),
    'musicGeneration' => MusicGenerationSettingsPage(controller: controller),
    'contact' => AiContactPage(
      controller: controller,
      senderId: args['contactId'] as String,
    ),
    'skills' => SkillsPage(
      controller: controller,
      store: await controller.aiSkills(args['senderId'] as String),
    ),
    'tasks' => TasksPage(controller: controller),
    'settings' => SettingsPage(
      controller: controller,
      preparingGoal: () => false,
    ),
    _ => throw ArgumentError('不支持的页面'),
  };
  if (!context.mounted) throw StateError('页面已关闭');
  Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => page));
}
