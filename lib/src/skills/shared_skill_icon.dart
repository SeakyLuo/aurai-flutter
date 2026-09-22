import 'package:flutter/material.dart';
import '../html_games/html_game_icon.dart';
import '../features/chat/settings_icon.dart';
import '../features/chat/conversation_icon.dart';
import '../features/chat/conversation_menu_icon.dart';
import '../features/chat/compose_icon.dart';
import '../features/chat/question_icon.dart';
import '../features/chat/attachment_action_icon.dart';
import '../features/chat/file_tool_icon.dart';
import '../features/chat/sidebar_action_icon.dart';
import '../features/chat/tool_semantic_icon.dart';

Widget? sharedSkillIcon(BuildContext context, String name) {
  const settings = {
    'discover': SettingsIconType.discover,
    'miniapp': SettingsIconType.miniapps,
    'tools': SettingsIconType.tools,
    'data': SettingsIconType.data,
    'task': SettingsIconType.tasks,
    'memory': SettingsIconType.memory,
    'personalization': SettingsIconType.personalization,
    'profile': SettingsIconType.personalInfo,
    'contacts': SettingsIconType.contacts,
    'balance': SettingsIconType.balance,
    'appearance': SettingsIconType.appearance,
    'model': SettingsIconType.model,
    'device': SettingsIconType.device,
    'chevron': SettingsIconType.chevron,
    'back': SettingsIconType.back,
    'check': SettingsIconType.check,
    'filter': SettingsIconType.filter,
  };
  const menu = {
    'pin': ConversationMenuIconType.pin,
    'unpin': ConversationMenuIconType.unpin,
    'rename': ConversationMenuIconType.rename,
    'archive': ConversationMenuIconType.archive,
    'unarchive': ConversationMenuIconType.unarchive,
    'delete': ConversationMenuIconType.delete,
  };
  final settingsType = settings[name];
  if (settingsType != null) return SettingsIcon(type: settingsType);
  final menuType = menu[name];
  if (menuType != null)
    return SizedBox.square(
      dimension: 24,
      child: FittedBox(
        child: ConversationMenuIcon(
          type: menuType,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  return switch (name) {
    'conversation' => const ConversationIcon(),
    'game' => const HtmlGameIcon(HtmlGameIconType.game),
    'compose' => const ComposeIcon(),
    'question' => const QuestionIcon(type: QuestionIconType.question),
    'close' => const QuestionIcon(type: QuestionIconType.close),
    'gallery' => const AttachmentActionIcon(
      type: AttachmentActionIconType.gallery,
    ),
    'document' => const FileToolIcon(type: FileToolIconType.read),
    'audio' => const AttachmentActionIcon(type: AttachmentActionIconType.audio),
    'video' => const AttachmentActionIcon(type: AttachmentActionIconType.video),
    'pdf' => const AttachmentActionIcon(type: AttachmentActionIconType.pdf),
    'presentation' => const AttachmentActionIcon(
      type: AttachmentActionIconType.presentation,
    ),
    'package' => const AttachmentActionIcon(
      type: AttachmentActionIconType.package,
    ),
    'image-search' => const ToolSemanticIcon(
      type: ToolSemanticIconType.imageSearch,
    ),
    'app-search' => const ToolSemanticIcon(
      type: ToolSemanticIconType.appSearch,
    ),
    'create-file' => const ToolSemanticIcon(
      type: ToolSemanticIconType.createFile,
    ),
    'group' => const SidebarActionIcon(type: SidebarActionIconType.group),
    _ => null,
  };
}
