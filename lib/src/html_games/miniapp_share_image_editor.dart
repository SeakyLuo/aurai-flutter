import 'package:flutter/material.dart';
import '../domain/miniapp_share.dart';
import '../features/chat/attachment_action_icon.dart';
import '../features/chat/conversation_menu_icon.dart';
import '../features/chat/header_action_menu.dart';
import 'miniapp_share_card.dart';

class MiniappShareImageEditor extends StatelessWidget {
  const MiniappShareImageEditor({
    super.key,
    required this.share,
    required this.onPick,
    required this.onRemove,
  });
  final MiniappShare share;
  final VoidCallback? onPick, onRemove;

  Future<void> _menu(BuildContext context) async {
    final action = await showHeaderActionMenu(
      context,
      items: [
        (
          value: 'pick',
          label: share.imagePath == null ? '选择分享图片' : '更换分享图片',
          icon: const AttachmentActionIcon(
            type: AttachmentActionIconType.gallery,
          ),
        ),
        if (share.imagePath != null)
          (
            value: 'remove',
            label: '移除分享图片',
            icon: ConversationMenuIcon(
              type: ConversationMenuIconType.delete,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
      ],
      destructiveValues: const {'remove'},
    );
    if (!context.mounted) return;
    if (action == 'pick') onPick!();
    if (action == 'remove') onRemove!();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '分享预览',
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        Builder(
          builder: (anchor) => Semantics(
            button: true,
            label: '编辑分享图片',
            child: MiniappShareCard(
              share: share,
              onTap: onPick == null ? null : () => _menu(anchor),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '点击卡片设置分享图片，未设置时使用小程序 logo。',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}
