import 'package:flutter/material.dart';
import '../features/chat/settings_icon.dart';
import '../features/chat/conversation_menu_icon.dart';
import '../features/chat/compose_icon.dart';
import '../features/chat/question_icon.dart';
import '../features/chat/attachment_action_icon.dart';
import '../features/chat/file_tool_icon.dart';

Widget? sharedSkillIcon(BuildContext context, String name) {
  const settings = {
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
    'compose' => const ComposeIcon(),
    'question' => const QuestionIcon(type: QuestionIconType.question),
    'close' => const QuestionIcon(type: QuestionIconType.close),
    'gallery' => const AttachmentActionIcon(
      type: AttachmentActionIconType.gallery,
    ),
    'document' => const FileToolIcon(type: FileToolIconType.read),
    _ => null,
  };
}
