import 'miniapp_forward.dart';
import '../features/chat/attachment_action_icon.dart';
import 'package:flutter/material.dart';

import '../app/glass_notice.dart';
import '../domain/error_message.dart';
import '../features/chat/header_action_menu.dart';
import '../features/chat/glass_surface.dart';
import '../features/chat/sidebar_action_icon.dart';
import '../scheduling/task_action_menu.dart';
import '../features/chat/settings_icon.dart';
import 'html_game_store.dart';
import 'miniapp_favorites.dart';
import 'miniapp_library_store.dart';

class MiniappFavoriteAction extends StatefulWidget {
  const MiniappFavoriteAction({
    super.key,
    required this.appId,
    required this.store,
    required this.onClose,
  });
  final String? appId;
  final VoidCallback onClose;
  final HtmlGameStore store;

  @override
  State<MiniappFavoriteAction> createState() => _MiniappFavoriteActionState();
}

class _MiniappFavoriteActionState extends State<MiniappFavoriteAction> {
  bool _busy = false;

  Future<void> _more(BuildContext anchor) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final entry = await MiniappLibraryStore(
        widget.store.database,
      ).entryForApp(widget.appId!);
      final favorites = MiniappFavorites(widget.store.database);
      final starred = await favorites.contains(entry);
      if (!anchor.mounted) return;
      final action = await showHeaderActionMenu(
        anchor,
        items: [
          (
            value: 'forward',
            label: '转发',
            icon: const AttachmentActionIcon(
              type: AttachmentActionIconType.forward,
            ),
          ),
          (
            value: 'favorite',
            label: starred ? '取消收藏' : '收藏',
            icon: SettingsIcon(
              type: starred
                  ? SettingsIconType.starFilled
                  : SettingsIconType.star,
              color: starred ? const Color(0xffe5ad24) : null,
            ),
          ),
        ],
      );
      if (action == 'forward') {
        if (mounted) await forwardMiniapp(context, entry);
        return;
      }
      if (action != 'favorite') return;
      int? removedAt;
      if (starred) {
        removedAt = await favorites.removeForUndo(entry);
      } else {
        await favorites.add(entry);
      }
      if (!messenger.mounted) return;
      messenger.showGlassSnackBar(
        SnackBar(
          content: Text(starred ? '已取消收藏' : '已收藏小程序'),
          persist: false,
          duration: const Duration(seconds: 6),
          action: removedAt == null
              ? null
              : SnackBarAction(
                  label: '撤销',
                  onPressed: () async {
                    try {
                      await favorites.add(entry, starredAt: removedAt);
                    } on Object catch (error) {
                      if (messenger.mounted)
                        messenger.showGlassSnackBar(
                          SnackBar(content: Text(errorMessage(error))),
                        );
                    }
                  },
                ),
        ),
      );
    } on Object catch (error) {
      if (messenger.mounted)
        messenger.showGlassSnackBar(
          SnackBar(content: Text(errorMessage(error))),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => GlassSurface(
    radius: 28,
    tintOpacity: .75,
    shadowOpacity: .65,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RoundAction(
            label: '关闭小程序',
            icon: Icons.close,
            onPressed: widget.onClose,
            iconWidget: Transform.rotate(
              angle: .7853981633974483,
              child: SidebarActionIcon(
                type: SidebarActionIconType.add,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          SizedBox(
            height: 18,
            child: VerticalDivider(
              width: 1,
              thickness: 1,
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: .5),
            ),
          ),
          Builder(
            builder: (anchor) => RoundAction(
              label: '更多',
              icon: Icons.more_vert_rounded,
              iconWidget: const TaskActionIcon('more'),
              onPressed: _busy || widget.appId == null
                  ? null
                  : () => _more(anchor),
            ),
          ),
        ],
      ),
    ),
  );
}
