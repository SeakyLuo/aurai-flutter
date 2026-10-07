import 'dart:convert';
import 'package:flutter/material.dart';
import '../../domain/tool_detail_target.dart';
import '../../domain/message_sender.dart';
import '../../domain/model_provider.dart';
import '../../html_games/miniapp_detail_page.dart';
import '../../html_games/miniapp_library_store.dart';
import '../../html_games/miniapp_symbol.dart';
import '../../scheduling/task_detail_page.dart';
import '../../skills/skill_detail_page.dart';
import '../../skills/skill_icon.dart';
import 'ai_contact_page.dart';
import 'chat_controller.dart';
import 'group_info_page.dart';
import 'image_action_scope.dart';
import 'model_detail_page.dart';
import 'model_provider_detail.dart';
import 'project_profile_page.dart';
import 'settings_icon.dart';

Widget objectDetailIcon(BuildContext context, ToolDetailTarget target) {
  if (target.icon != null) return SkillIcon(target.icon!);
  return switch (target.type) {
    ToolDetailType.miniapp || ToolDetailType.miniappPublication =>
      MiniappSymbol(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ToolDetailType.aiContact ||
    ToolDetailType.group => const SettingsIcon(type: SettingsIconType.contacts),
    ToolDetailType.scheduledTask => const SettingsIcon(
      type: SettingsIconType.tasks,
    ),
    ToolDetailType.model => const SettingsIcon(type: SettingsIconType.model),
    ToolDetailType.provider => const SettingsIcon(
      type: SettingsIconType.modelProvider,
    ),
    ToolDetailType.skill => const SkillIcon('skill'),
    ToolDetailType.project => const SkillIcon('file'),
  };
}

Future<void> openObjectDetail(
  BuildContext context,
  ToolDetailTarget target,
) async {
  final controller = ImageActionScope.of(context);
  final Widget page;
  switch (target.type) {
    case ToolDetailType.skill:
      final store = await controller.aiSkills(MessageSender.localUser.id);
      await store.reload();
      final skill = store.readId(target.id);
      page = SkillDetailPage(
        controller: controller,
        store: store,
        skillId: skill.id,
      );
    case ToolDetailType.project:
      final project = await controller.projects.read(target.id);
      page = ProjectProfilePage(controller: controller, project: project);
    case ToolDetailType.aiContact:
      page = AiContactPage(controller: controller, senderId: target.id);
    case ToolDetailType.scheduledTask:
      page = TaskDetailPage(controller: controller, id: target.id);
    case ToolDetailType.miniapp || ToolDetailType.miniappPublication:
      final store = controller.htmlStore;
      final library = MiniappLibraryStore(store.database);
      final entry = target.type == ToolDetailType.miniappPublication
          ? await library.entryForPublication(target.id)
          : await library.entryForApp(target.id);
      page = MiniappDetailPage(entry: entry, store: store);
    case ToolDetailType.model:
      // Provider-local model names are only unique within their provider.
      final identity = (jsonDecode(target.id) as List).cast<String>();
      page = ModelDetailPage(
        controller: controller,
        service: ModelService.byName(identity[0]),
        model: identity[1],
      );
    case ToolDetailType.provider:
      page = ModelProviderDetail(
        controller: controller,
        service: ModelService.byName(target.id),
        accountOnly: false,
      );
    case ToolDetailType.group:
      final conversation = await controller.conversationDetails(target.id);
      page = GroupInfoPage(
        controller: controller,
        conversation: conversation,
        onPin: () => controller.toggleConversationPin(target.id),
      );
  }
  if (!context.mounted) return;
  await Navigator.of(
    context,
  ).push<void>(MaterialPageRoute(builder: (_) => page));
}
