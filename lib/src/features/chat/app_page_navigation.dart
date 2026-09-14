import 'package:flutter/material.dart';
import '../../skills/skills_page.dart';
import '../../scheduling/tasks_page.dart';
import 'ai_contact_page.dart';
import 'chat_controller.dart';
import 'home_navigation.dart';
import 'settings_page.dart';

Future<void> navigateAppPage(
  BuildContext context,
  ChatController controller,
  Map<String, Object?> args,
) async {
  if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
    throw StateError('请先回到 Aurai，再打开页面');
  }
  if (args['page'] == 'conversation') {
    await openHomeConversation(
      context,
      controller,
      args['conversationId'] as String,
    );
    return;
  }
  final page = switch (args['page']) {
    'contact' => AiContactPage(
      controller: controller,
      senderId: args['contactId'] as String,
    ),
    'skills' => SkillsPage(
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
