import 'package:flutter/material.dart';

import '../features/chat/attachment_action_icon.dart';
import '../features/chat/conversation_menu_icon.dart';
import '../features/chat/glass_surface.dart';
import '../features/chat/header_action_menu.dart';
import '../features/chat/settings_appearance.dart';
import 'miniapp_icon.dart';

class MiniappIconEditor extends StatelessWidget {
  const MiniappIconEditor({
    super.key,
    required this.path,
    required this.onPick,
    required this.onRemove,
  });

  final String? path;
  final VoidCallback? onPick;
  final VoidCallback? onRemove;

  Future<void> _menu(BuildContext context) async {
    final action = await showHeaderActionMenu(
      context,
      items: [
        (
          value: 'pick',
          label: path == null ? '选择图片' : '更换图片',
          icon: const AttachmentActionIcon(
            type: AttachmentActionIconType.gallery,
          ),
        ),
        if (path != null)
          (
            value: 'remove',
            label: '移除图标',
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
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 28),
      child: Builder(
        builder: (anchor) => Semantics(
          button: true,
          label: '编辑小程序图标',
          child: Tooltip(
            message: '编辑图标',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPick == null ? null : () => _menu(anchor),
                borderRadius: BorderRadius.circular(24),
                child: SizedBox.square(
                  dimension: 96,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: settingsFieldColor(context),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Center(
                            child: MiniappIcon(
                              path: path,
                              size: path == null ? 36 : 96,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GlassSurface(
                          radius: 16,
                          child: ColoredBox(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? const Color(0x38404040)
                                : const Color(0x20707070),
                            child: Padding(
                              padding: const EdgeInsets.all(7),
                              child: SizedBox.square(
                                dimension: 18,
                                child: ConversationMenuIcon(
                                  type: ConversationMenuIconType.rename,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                            ),
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
    ),
  );
}
