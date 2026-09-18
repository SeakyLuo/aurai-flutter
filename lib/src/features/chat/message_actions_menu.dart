import '../../storage/quick_reply_recents.dart';
import 'message_action.dart';
export 'message_action.dart';
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

Future<MessageAction?> showMessageActionsMenu(
  BuildContext context, {
  required AgentMessage message,
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
  final options = {for (final option in quickReplyOptions) option.$4: option};
  final visibleKeys = {
    ...recent.where(options.containsKey),
    ...quickReplyOptions.take(5).map((option) => option.$4),
  }.take(5);
  return showModalBottomSheet<MessageAction>(
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
      final actions = [
        if (allowHistory)
          (
            MessageAction.history,
            SettingsIcon(
              type: SettingsIconType.tasks,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            '查看历史',
          ),
        if (allowStatistics)
          (
            MessageAction.statistics,
            SettingsIcon(
              type: SettingsIconType.data,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            '查看统计',
          ),
        if (message.htmlGame != null &&
            message.htmlGame!.displayMode != 'inline')
          (
            MessageAction.fullscreen,
            const HtmlGameIcon(HtmlGameIconType.expand),
            '全屏运行',
          ),
        if (allowQuote) (MessageAction.quote, const QuoteIcon(), '引用'),
        if (allowForward)
          (
            MessageAction.forward,
            AttachmentActionIcon(
              type: AttachmentActionIconType.forward,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            '转发',
          ),
        if (message.text.isNotEmpty) ...[
          (
            MessageAction.copy,
            const CopyIcon(),
            message.htmlGame != null ? '复制标题' : '复制',
          ),
          (MessageAction.select, const TextSelectionIcon(), '选择文本'),
        ],
        if (allowEditing && message.role == AgentMessageRole.user)
          (
            MessageAction.edit,
            ConversationMenuIcon(
              type: ConversationMenuIconType.rename,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            '编辑消息',
          ),
        if (allowRecall)
          (
            MessageAction.recall,
            ConversationMenuIcon(
              type: ConversationMenuIconType.recall,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    for (final (action, icon, label, key) in visibleKeys.map(
                      (key) => options[key]!,
                    ))
                      Expanded(
                        child: Tooltip(
                          message: label,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () => Navigator.pop(context, action),
                            child: Container(
                              height: 52,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: sentQuickReplyKeys.contains(key)
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer
                                    : null,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Text(
                                icon,
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: key == 'plus_one'
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
                            final action = await showQuickReplyPicker(
                              context,
                              selectedKeys: sentQuickReplyKeys,
                            );
                            if (context.mounted && action != null)
                              Navigator.pop(context, action);
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
              for (final (action, icon, label) in actions)
                InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => Navigator.pop(context, action),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        icon,
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
