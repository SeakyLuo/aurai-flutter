import '../../domain/message_sender.dart';
import 'ai_contact_page.dart';
import 'personal_info_page.dart';
import 'header_action_menu.dart';
import 'package:flutter/material.dart';
import '../../domain/agent_models.dart';
import '../../html_games/html_game_view.dart';
import '../../storage/group_message_search.dart';
import 'attachment_action_icon.dart';
import 'chat_controller.dart';
import 'member_avatar.dart';
import 'message_item.dart';
import 'message_time.dart';
import 'settings_icon.dart';

class StarredMessageTile extends StatelessWidget {
  const StarredMessageTile({
    super.key,
    required this.result,
    required this.conversationId,
    required this.conversationTitle,
    required this.controller,
    required this.onLocate,
    required this.onRemove,
    this.selectionMode = false,
  });
  final GroupMessageSearchResult result;
  final String conversationId, conversationTitle;
  final ChatController controller;
  final VoidCallback onLocate, onRemove;
  final bool selectionMode;

  void _openProfile(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => result.sender.id == MessageSender.localUser.id
            ? PersonalInfoPage(memory: controller.memory)
            : AiContactPage(controller: controller, senderId: result.sender.id),
      ),
    );
  }

  Future<void> _more(BuildContext context) async {
    final action = await showHeaderActionMenu(
      context,
      items: [
        (
          value: 'locate',
          label: '定位原消息',
          icon: const AttachmentActionIcon(
            type: AttachmentActionIconType.locate,
          ),
        ),
        (
          value: 'remove',
          label: '取消收藏',
          icon: const SettingsIcon(
            type: SettingsIconType.starFilled,
            color: Color(0xffe5ad24),
          ),
        ),
      ],
    );
    if (!context.mounted) return;
    if (action == 'locate') onLocate();
    if (action == 'remove') onRemove();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Semantics(
                button: true,
                label: '查看${result.sender.name}的资料',
                child: GestureDetector(
                  onTap: () => _openProfile(context),
                  child: MemberAvatar(sender: result.sender, size: 32),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.sender.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),
                    if (conversationTitle.isNotEmpty)
                      Text(
                        conversationTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (selectionMode)
                const SizedBox(width: 40)
              else
                Builder(
                  builder: (buttonContext) => IconButton(
                    tooltip: '更多',
                    onPressed: () => _more(buttonContext),
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (result.html case final card?)
            HtmlGameView(
              key: ValueKey(result.id),
              card: card,
              messageId: result.id,
              conversationId: conversationId,
              store: controller.htmlGames,
            )
          else
            MessageItem(
              message: AgentMessage(
                id: result.id,
                role: result.role,
                senderId: result.sender.id,
                sender: result.sender,
                text: result.text,
                createdAt: result.createdAt,
                images: result.images,
                files: result.files,
                interactive: result.interactive,
                isGroupMessage: true,
              ),
              onEdit: null,
              groupBubble: true,
              readOnly: true,
              onLocate: onLocate,
              onInteractiveClick: (_, _, _, {value}) async {
                onLocate();
                return null;
              },
            ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              messageTime(result.createdAt),
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
