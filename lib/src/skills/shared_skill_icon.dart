import 'package:flutter/material.dart';
import '../html_games/html_game_icon.dart';
import '../html_games/miniapp_symbol.dart';
import '../features/chat/settings_icon.dart';
import '../features/chat/conversation_icon.dart';
import '../features/chat/conversation_menu_icon.dart';
import '../features/chat/compose_icon.dart';
import '../features/chat/question_icon.dart';
import '../features/chat/attachment_action_icon.dart';
import '../features/chat/file_tool_icon.dart';
import '../features/chat/sidebar_action_icon.dart';
import '../features/chat/tool_semantic_icon.dart';
import '../features/chat/message_quote_view.dart';
import '../features/chat/text_selection_icon.dart';

Widget? sharedSkillIcon(BuildContext context, String name) {
  final color = Theme.of(context).colorScheme.onSurfaceVariant;
  const settings = {
    'discover': SettingsIconType.discover,
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
    'speech': SettingsIconType.sound,
    'device': SettingsIconType.device,
    'chevron': SettingsIconType.chevron,
    'back': SettingsIconType.back,
    'check': SettingsIconType.check,
    'filter': SettingsIconType.filter,
    'star': SettingsIconType.star,
    'permission': SettingsIconType.permission,
  };
  const menu = {
    'pin': ConversationMenuIconType.pin,
    'unpin': ConversationMenuIconType.unpin,
    'rename': ConversationMenuIconType.rename,
    'archive': ConversationMenuIconType.archive,
    'unarchive': ConversationMenuIconType.unarchive,
    'delete': ConversationMenuIconType.delete,
    'mark': ConversationMenuIconType.mark,
    'copy': ConversationMenuIconType.copy,
    'announcement': ConversationMenuIconType.announcement,
    'recall': ConversationMenuIconType.recall,
    'retry': ConversationMenuIconType.retry,
  };
  if (name == 'text') {
    return SizedBox.square(
      dimension: 24,
      child: Center(
        child: Text(
          'Aa',
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            letterSpacing: -1.4,
            height: 1,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
  final settingsType = settings[name];
  if (settingsType != null)
    return SettingsIcon(type: settingsType, color: color);
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
    'miniapp' => MiniappSymbol(color: color),
    'conversation' => const ConversationIcon(),
    'quote' => const SizedBox.square(
      dimension: 24,
      child: FittedBox(child: QuoteIcon()),
    ),
    'select-text' => const SizedBox.square(
      dimension: 24,
      child: FittedBox(child: TextSelectionIcon()),
    ),
    'game' => const HtmlGameIcon(HtmlGameIconType.game),
    'compose' => ComposeIcon(color: color),
    'question' => const QuestionIcon(type: QuestionIconType.question),
    'close' => const QuestionIcon(type: QuestionIconType.close),
    'gallery' => AttachmentActionIcon(
      color: color,
      type: AttachmentActionIconType.gallery,
    ),
    'document' => const FileToolIcon(type: FileToolIconType.read),
    'audio' => AttachmentActionIcon(
      color: color,
      type: AttachmentActionIconType.audio,
    ),
    'video' => AttachmentActionIcon(
      color: color,
      type: AttachmentActionIconType.video,
    ),
    'pdf' => AttachmentActionIcon(
      color: color,
      type: AttachmentActionIconType.pdf,
    ),
    'presentation' => AttachmentActionIcon(
      color: color,
      type: AttachmentActionIconType.presentation,
    ),
    'package' => AttachmentActionIcon(
      color: color,
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
    'group' => SidebarActionIcon(
      type: SidebarActionIconType.group,
      color: color,
    ),
    'forward' => AttachmentActionIcon(
      color: color,
      type: AttachmentActionIconType.forward,
    ),
    'word' => AttachmentActionIcon(
      color: color,
      type: AttachmentActionIconType.word,
    ),
    'excel' => AttachmentActionIcon(
      color: color,
      type: AttachmentActionIconType.excel,
    ),
    'ebook' => AttachmentActionIcon(
      color: color,
      type: AttachmentActionIconType.ebook,
    ),
    'share-file' => const ToolSemanticIcon(
      type: ToolSemanticIconType.shareFile,
    ),
    _ => null,
  };
}
