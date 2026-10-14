import 'package:flutter/material.dart';

import '../features/chat/menu_press_highlight.dart';
import '../features/chat/settings_appearance.dart';
import '../features/chat/settings_icon.dart';
import '../features/chat/sidebar_action_icon.dart';
import 'miniapp_entry.dart';
import 'miniapp_icon.dart';

/// The pull-down launcher uses the same icons and controls as the library.
class MiniappHomeContent extends StatelessWidget {
  const MiniappHomeContent({
    super.key,
    required this.recent,
    required this.favorites,
    required this.loading,
    required this.opening,
    required this.onSearch,
    required this.onRecent,
    required this.onManage,
    required this.onBrowse,
    required this.onOpen,
    required this.onMenu,
  });
  final List<MiniappEntry> recent, favorites;
  final bool loading, opening;
  final VoidCallback onSearch, onRecent, onManage, onBrowse;
  final ValueChanged<MiniappEntry> onOpen;
  final Future<void> Function(BuildContext anchor, MiniappEntry entry) onMenu;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          settingsHeaderHeight(context) + 16,
          20,
          MediaQuery.paddingOf(context).bottom + 100,
        ),
        children: [
          Material(
            color: Color.alphaBlend(
              Theme.of(context).colorScheme.onSurface.withValues(alpha: .06),
              Theme.of(context).colorScheme.surface,
            ),
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onSearch,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    const SidebarActionIcon(type: SidebarActionIconType.search),
                    const SizedBox(width: 10),
                    Text(
                      '搜索小程序',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 26),
          _header(context, '最近使用', '全部', onRecent),
          const SizedBox(height: 12),
          if (loading && recent.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (recent.isEmpty)
            _empty(context, '还没有使用过小程序', '浏览小程序', onBrowse)
          else
            _grid(recent),
          const SizedBox(height: 28),
          _header(context, '我的小程序', '管理', onManage),
          const SizedBox(height: 12),
          if (!loading && favorites.isEmpty)
            _empty(context, '收藏的小程序会显示在这里', '去收藏', onBrowse)
          else
            _grid(favorites),
        ],
      ),
    ),
  );

  Widget _header(
    BuildContext context,
    String title,
    String action,
    VoidCallback onPressed,
  ) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          minimumSize: const Size(48, 36),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(action),
            const SizedBox(width: 2),
            const SizedBox.square(
              dimension: 18,
              child: SettingsIcon(type: SettingsIconType.chevron),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _empty(
    BuildContext context,
    String text,
    String action,
    VoidCallback onPressed,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Column(
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        TextButton(onPressed: onPressed, child: Text(action)),
      ],
    ),
  );

  Widget _grid(List<MiniappEntry> entries) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth / 4;
      return Wrap(
        spacing: 0,
        runSpacing: 16,
        children: [
          for (final entry in entries)
            SizedBox(
              width: width,
              child: Builder(
                builder: (anchor) => Material(
                  color: Colors.transparent,
                  child: MenuPressHighlight(
                    borderRadius: BorderRadius.circular(18),
                    onLongPressStart: opening
                        ? null
                        : (_) => onMenu(anchor, entry),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: opening ? null : () => onOpen(entry),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                        child: Column(
                          children: [
                            MiniappIcon(
                              path: entry.iconPath,
                              asset: entry.iconAsset,
                              size: 56,
                            ),
                            const SizedBox(height: 9),
                            Text(
                              entry.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
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
}
