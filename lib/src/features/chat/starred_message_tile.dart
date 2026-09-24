import '../../domain/message_sender.dart';
import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import '../../html_games/miniapp_favorites.dart';
import '../../html_games/miniapp_forward.dart';
import '../../html_games/miniapp_library_store.dart';
import 'ai_contact_page.dart';
import 'personal_info_page.dart';
import 'header_action_menu.dart';
import 'html_message_more_button.dart';
import 'package:flutter/material.dart';
import '../../domain/agent_models.dart';
import '../../html_games/html_game_icon.dart';
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
    required this.starredAt,
    required this.conversationId,
    required this.conversationTitle,
    required this.controller,
    required this.onLocate,
    required this.onRemove,
    this.contentPadding = const EdgeInsets.symmetric(vertical: 14),
    this.selectionMode = false,
  });
  final GroupMessageSearchResult result;
  final DateTime starredAt;
  final String conversationId, conversationTitle;
  final ChatController controller;
  final VoidCallback onLocate, onRemove;
  final EdgeInsetsGeometry contentPadding;
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

  Future<void> _showMenu(BuildContext context) async {
    final iconColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black;
    final action = await showHeaderActionMenu(
      context,
      items: [
        (
          value: 'locate',
          label: '定位原消息',
          icon: AttachmentActionIcon(
            type: AttachmentActionIconType.locate,
            color: iconColor,
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

  Future<void> _showMiniappMenu(BuildContext context) async {
    final card = result.html!;
    final iconColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final entry = await MiniappLibraryStore(
        controller.htmlGames.database,
      ).entryForApp(card.appId!);
      final favorites = MiniappFavorites(controller.htmlGames.database);
      final starred = await favorites.contains(entry);
      if (!context.mounted) return;
      final action = await showHeaderActionMenu(
        context,
        items: [
          if (card.displayMode != 'inline')
            (
              value: 'fullscreen',
              label: '全屏运行',
              icon: HtmlGameIcon(HtmlGameIconType.expand, color: iconColor),
            ),
          (
            value: 'forward',
            label: '转发',
            icon: AttachmentActionIcon(
              type: AttachmentActionIconType.forward,
              color: iconColor,
            ),
          ),
          (
            value: 'favorite',
            label: starred ? '取消收藏' : '收藏',
            icon: SettingsIcon(
              type: starred
                  ? SettingsIconType.starFilled
                  : SettingsIconType.star,
              color: starred ? const Color(0xffe5ad24) : iconColor,
            ),
          ),
        ],
      );
      if (!context.mounted) return;
      if (action == 'fullscreen') {
        await HtmlGameView(
          card: card,
          messageId: result.id,
          conversationId: conversationId,
          store: controller.htmlGames,
          backLabel: '返回收藏',
        ).openFullscreen(context);
      }
      if (action == 'forward') await forwardMiniapp(context, entry);
      if (action == 'favorite') {
        if (starred) {
          await favorites.remove(entry);
        } else {
          await favorites.add(entry);
        }
        if (messenger.mounted) {
          messenger.showGlassSnackBar(
            SnackBar(content: Text(starred ? '已取消收藏小程序' : '已收藏小程序')),
          );
        }
      }
    } on Object catch (error) {
      if (messenger.mounted) {
        messenger.showGlassSnackBar(
          SnackBar(content: Text(errorMessage(error))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      type: MaterialType.transparency,
      child: Builder(
        builder: (menuContext) => InkWell(
          onTap: selectionMode ? null : onLocate,
          onLongPress: selectionMode ? null : () => _showMenu(menuContext),
          child: Padding(
            padding: contentPadding,
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
                    Text(
                      messageTime(starredAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (result.html case final card?)
                  Stack(
                    children: [
                      IgnorePointer(
                        child: HtmlGameView(
                          key: ValueKey(result.id),
                          card: card,
                          messageId: result.id,
                          conversationId: conversationId,
                          store: controller.htmlGames,
                        ),
                      ),
                      if (!selectionMode)
                        Positioned(
                          top: HtmlMessageMoreButton.top,
                          right: HtmlMessageMoreButton.right,
                          child: Builder(
                            builder: (buttonContext) => HtmlMessageMoreButton(
                              label: '小程序操作',
                              onPressed: () => _showMiniappMenu(buttonContext),
                            ),
                          ),
                        ),
                    ],
                  )
                else
                  IgnorePointer(
                    child: MessageItem(
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
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
