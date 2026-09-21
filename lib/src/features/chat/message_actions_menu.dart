import '../../storage/quick_reply_recents.dart';
import 'message_action.dart';
export 'message_action.dart';
import '../../domain/quick_reply_option.dart';
import 'quick_reply_picker.dart';
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

Future<MessageMenuResult?> showMessageActionsMenu(
  BuildContext context, {
  required AgentMessage message,
  bool allowStar = false,
  bool starred = false,
  bool allowEditing = true,
  bool allowStatistics = false,
  bool allowHistory = false,
  bool allowQuote = false,
  bool allowRecall = false,
  bool allowForward = false,
  bool allowQuickReply = false,
  Set<String> sentQuickReplyKeys = const {},
}) async {
  final recent = allowQuickReply
      ? await QuickReplyRecents.load()
      : const <String>[];
  if (!context.mounted) return null;
  final options = quickReplyOptionsByKey;
  final visibleKeys = {
    ...recent.where(options.containsKey),
    ...quickReplyOptions.take(5).map((option) => option.key),
  }.take(5);
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
        if (allowHistory)
          (
            const MessageActionResult(MessageAction.history),
            SettingsIcon(type: SettingsIconType.tasks, color: iconColor),
            '查看历史',
          ),
        if (allowStatistics)
          (
            const MessageActionResult(MessageAction.statistics),
            SettingsIcon(type: SettingsIconType.data, color: iconColor),
            '查看统计',
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
            '转发',
          ),
        if (message.text.isNotEmpty)
          (
            const MessageActionResult(MessageAction.copy),
            CopyIcon(color: iconColor),
            message.htmlGame != null ? '复制标题' : '复制',
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
        if (message.text.isNotEmpty)
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
                        child: Semantics(
                          label: option.emoji,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () => Navigator.pop(
                              context,
                              MessageQuickReplyResult(option),
                            ),
                            child: Container(
                              height: 52,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: sentQuickReplyKeys.contains(option.key)
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer
                                    : null,
                                borderRadius: BorderRadius.circular(24),
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
                      child: Tooltip(
                        message: '更多表情',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () async {
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
                          child: Container(
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              shape: BoxShape.circle,
                            ),
                            child: const SidebarActionIcon(
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
                child: Text(
                  messageTime(message.createdAt),
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
  );
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
    appBar: SettingsAppBar(
      title: '选择文本',
      onBack: () => Navigator.maybePop(context),
    ),
    body: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
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
  );
}
