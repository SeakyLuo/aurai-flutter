import '../../html_games/html_game_icon.dart';
import 'attachment_action_icon.dart';
import 'message_quote_view.dart';
import 'settings_icon.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/agent_models.dart';
import 'glass_surface.dart';
import 'message_time.dart';
import 'copy_icon.dart';
import 'conversation_menu_icon.dart';
import 'text_selection_icon.dart';
import 'settings_appearance.dart';

enum MessageAction { copy, select, edit, quote, recall, forward, fullscreen }

Future<MessageAction?> showMessageActionsMenu(
  BuildContext context, {
  required AgentMessage message,
  required Offset position,
  bool allowEditing = true,
  bool allowQuote = false,
  bool allowRecall = false,
  bool allowForward = false,
}) => showGeneralDialog<MessageAction>(
  context: context,
  requestFocus: false,
  barrierDismissible: true,
  barrierLabel: '关闭消息菜单',
  barrierColor: Colors.transparent,
  transitionDuration: const Duration(milliseconds: 160),
  pageBuilder: (context, animation, secondaryAnimation) {
    final media = MediaQuery.of(context);
    final width = math.min(
      232.0,
      media.size.width - media.padding.horizontal - 16,
    );
    final availableHeight =
        media.size.height -
        media.padding.top -
        math.max(media.padding.bottom, media.viewInsets.bottom) -
        16;
    final actions = [
      if (message.htmlGame != null && message.htmlGame!.displayMode != 'inline')
        (
          MessageAction.fullscreen,
          const HtmlGameIcon(HtmlGameIconType.expand),
          '全屏运行',
        ),
      if (allowRecall)
        (
          MessageAction.recall,
          SettingsIcon(
            type: SettingsIconType.back,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          '撤回',
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
    ];
    final height = math.min(
      availableHeight,
      64 + actions.length * 46 * math.max(1, media.textScaler.scale(14) / 14),
    );
    final left = (position.dx - width / 2).clamp(
      media.padding.left + 8,
      media.size.width - media.padding.right - width - 8,
    );
    final top = (position.dy + 12).clamp(
      media.padding.top + 8,
      media.padding.top + 8 + availableHeight - height,
    );
    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          width: width,
          child: FadeTransition(
            opacity: animation,
            child: GlassSurface(
              radius: 24,
              child: Material(
                type: MaterialType.transparency,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: media.padding.top + 8 + availableHeight - top,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                          child: Text(
                            messageTime(message.createdAt),
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
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
                                vertical: 11,
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
                ),
              ),
            ),
          ),
        ),
      ],
    );
  },
);

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
