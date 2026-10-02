import '../../storage/quick_reply_recents.dart';
import 'message_action.dart';
export 'message_action.dart';
import '../../domain/quick_reply_option.dart';
import 'quick_reply_groups.dart';
import 'quick_reply_picker.dart';
import 'emoji_button.dart';
import 'sidebar_action_icon.dart';
import '../../html_games/html_game_icon.dart';
import 'attachment_action_icon.dart';
import 'message_quote_view.dart';
import 'settings_icon.dart';

import 'package:flutter/material.dart';

import '../../domain/agent_models.dart';
import 'message_time.dart';
import 'copy_icon.dart';
import 'conversation_menu_icon.dart';
import 'text_selection_icon.dart';
import 'settings_appearance.dart';
import 'menu_press_highlight.dart';

Future<MessageMenuResult?> showMessageActionsMenu(
  BuildContext context, {
  required AgentMessage message,
  bool allowStar = false,
  bool allowGroupMarks = false,
  bool pinned = false,
  bool groupFavorite = false,
  bool allowCopy = true,
  bool allowSelect = true,
  bool starred = false,
  bool allowEditing = true,
  bool allowHistory = false,
  bool allowVisibility = false,
  bool allowQuote = false,
  bool allowRecall = false,
  bool allowRetry = false,
  bool allowForward = false,
  bool allowBranch = false,
  bool allowQuickReply = false,
  Set<String> sentQuickReplyKeys = const {},
}) async {
  final recent = allowQuickReply
      ? await QuickReplyRecents.load()
      : const <String>[];
  if (!context.mounted) return null;
  final options = quickReplyOptionsByKey;
  final visibleKeys = recentQuickReplyKeys(recent, 5);
  return showModalBottomSheet<MessageMenuResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    barrierColor: Colors.black.withValues(alpha: .24),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      final media = MediaQuery.of(context);
      final iconColor = Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.onSurfaceVariant
          : const Color(0xff222222);
      final actions = [
        if (allowRetry)
          (
            const MessageActionResult(MessageAction.retry),
            ConversationMenuIcon(
              type: ConversationMenuIconType.retry,
              color: iconColor,
            ),
            '重试',
          ),
        if (allowHistory)
          (
            const MessageActionResult(MessageAction.history),
            SettingsIcon(type: SettingsIconType.tasks, color: iconColor),
            '查看历史',
          ),
        if (message.htmlGame != null &&
            message.htmlGame!.displayMode != 'inline')
          (
            const MessageActionResult(MessageAction.fullscreen),
            HtmlGameIcon(HtmlGameIconType.expand, color: iconColor),
            '全屏运行',
          ),
        if (allowQuote)
          (
            const MessageActionResult(MessageAction.quote),
            QuoteIcon(color: iconColor),
            '引用',
          ),
        if (allowForward)
          (
            const MessageActionResult(MessageAction.forward),
            AttachmentActionIcon(
              type: AttachmentActionIconType.forward,
              color: iconColor,
            ),
            message.htmlGame != null ? '分享' : '转发',
          ),
        if (allowBranch)
          (
            const MessageActionResult(MessageAction.branch),
            ConversationMenuIcon(
              type: ConversationMenuIconType.branch,
              color: iconColor,
            ),
            '在新聊天继续',
          ),
        if (allowCopy && message.htmlGame == null && message.text.isNotEmpty)
          (
            const MessageActionResult(MessageAction.copy),
            CopyIcon(color: iconColor),
            '复制',
          ),
        if (allowStar)
          (
            const MessageActionResult(MessageAction.star),
            SettingsIcon(
              type: starred
                  ? SettingsIconType.starFilled
                  : SettingsIconType.star,
              color: starred ? const Color(0xffe5ad24) : iconColor,
            ),
            starred ? '取消收藏' : '收藏',
          ),
        if (allowGroupMarks) ...[
          (
            const MessageActionResult(MessageAction.pin),
            ConversationMenuIcon(
              type: pinned
                  ? ConversationMenuIconType.removeTop
                  : ConversationMenuIconType.toTop,
              color: iconColor,
            ),
            pinned ? '取消置顶' : '置顶消息',
          ),
          (
            const MessageActionResult(MessageAction.groupFavorite),
            ConversationMenuIcon(
              type: groupFavorite
                  ? ConversationMenuIconType.unmark
                  : ConversationMenuIconType.mark,
              color: iconColor,
            ),
            groupFavorite ? '取消群标记' : '添加群标记',
          ),
        ],
        if (allowSelect &&
            message.htmlGame == null &&
            message.miniappShare == null &&
            message.text.isNotEmpty)
          (
            const MessageActionResult(MessageAction.select),
            TextSelectionIcon(color: iconColor),
            '选择文本',
          ),
        if (allowEditing && message.role == AgentMessageRole.user)
          (
            const MessageActionResult(MessageAction.edit),
            ConversationMenuIcon(
              type: ConversationMenuIconType.rename,
              color: iconColor,
            ),
            '编辑消息',
          ),
        if (allowRecall)
          (
            const MessageActionResult(MessageAction.recall),
            ConversationMenuIcon(
              type: ConversationMenuIconType.recall,
              color: iconColor,
            ),
            '撤回',
          ),
      ];
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * .78),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (allowQuickReply) ...[
                Row(
                  children: [
                    for (final option in visibleKeys.map(
                      (key) => options[key]!,
                    ))
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Semantics(
                            label: option.emoji,
                            button: true,
                            selected: sentQuickReplyKeys.contains(option.key),
                            child: EmojiButton(
                              selected: sentQuickReplyKeys.contains(option.key),
                              onTap: () => Navigator.pop(
                                context,
                                MessageQuickReplyResult(option),
                              ),
                              child: Text(
                                option.emoji,
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: option.key == 'plus_one'
                                      ? FontWeight.w600
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Tooltip(
                          message: '更多表情',
                          child: IconButton(
                            style: IconButton.styleFrom(
                              fixedSize: const Size.square(44),
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: .10),
                              shape: const CircleBorder(),
                            ),
                            onPressed: () async {
                              final option = await showQuickReplyPicker(
                                context,
                                selectedKeys: sentQuickReplyKeys,
                              );
                              if (context.mounted && option != null) {
                                Navigator.pop(
                                  context,
                                  MessageQuickReplyResult(option),
                                );
                              }
                            },
                            icon: const SidebarActionIcon(
                              type: SidebarActionIconType.add,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                child: DefaultTextStyle(
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(messageTime(message.createdAt))),
                      if (allowVisibility && message.hasRestrictedAudience)
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.pop(
                            context,
                            const MessageActionResult(MessageAction.visibility),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(message.visibilityLabel),
                                const SizedBox(width: 4),
                                SizedBox.square(
                                  dimension: 16,
                                  child: FittedBox(
                                    child: SettingsIcon(
                                      type: SettingsIconType.chevron,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              for (final (result, icon, label) in actions)
                InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => Navigator.pop(context, result),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        SizedBox.square(
                          dimension: 24,
                          child: FittedBox(child: icon),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            label,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  ).whenComplete(MenuPressHighlight.dismissActive);
}

class MessageTextSelectionPage extends StatefulWidget {
  const MessageTextSelectionPage({super.key, required this.text});
  final String text;

  @override
  State<MessageTextSelectionPage> createState() =>
      _MessageTextSelectionPageState();
}

class _MessageTextSelectionPageState extends State<MessageTextSelectionPage> {
  late final _text = TextEditingController(text: widget.text);
  final _focus = FocusNode();

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: SettingsAppBar(
      title: '选择文本',
      onBack: () => Navigator.maybePop(context),
    ),
    body: SettingsPageBody(
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: settingsPagePadding(
            context,
            const EdgeInsets.fromLTRB(24, 8, 24, 24),
          ),
          child: TextField(
            controller: _text,
            focusNode: _focus,
            readOnly: true,
            showCursor: false,
            maxLines: null,
            style: const TextStyle(fontSize: 16, height: 1.65),
            decoration: const InputDecoration(
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    ),
  );
}
