import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../features/chat/glass_surface.dart';
import '../features/chat/settings_icon.dart';
import '../features/chat/conversation_menu_icon.dart';
import '../scheduling/task_action_menu.dart';

Future<String?> showSkillActionMenu(
  BuildContext context,
  Offset position,
  bool enabled, {
  bool showEdit = false,
  bool installed = true,
  bool canDelete = true,
  bool canInstall = false,
}) => _showSkillMenu(context, position, [
  if (showEdit) ('edit', '编辑'),
  if (canInstall) ('install', '安装'),
  if (installed) ('uninstall', '卸载'),
  if (installed) (enabled ? 'pause' : 'resume', enabled ? '停用' : '启用'),
  if (canDelete) ('delete', '删除'),
]);

Future<String?> showSkillPreferencesMenu(
  BuildContext context,
  Offset position, {
  bool library = false,
  bool showPermissions = true,
}) => _showSkillMenu(context, position, [
  ('create', '新建'),
  if (!library) ('install', '去安装'),
  if (showPermissions) ('permissions', '偏好权限'),
  ('sort', '排序'),
]);

Future<String?> _showSkillMenu(
  BuildContext context,
  Offset position,
  List<(String, String)> entries,
) {
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭技能菜单',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, _) {
      final media = MediaQuery.of(context);
      final width = math.min(
        212.0,
        media.size.width - media.padding.horizontal - 16,
      );
      final height = entries.length * 54.0 + 14;
      final left = position.dx.clamp(
        media.padding.left + 8,
        media.size.width - media.padding.right - width - 8,
      );
      final top = position.dy.clamp(
        media.padding.top + 8,
        math.max(
          media.padding.top + 8,
          media.size.height - media.padding.bottom - height - 8,
        ),
      );
      return Stack(
        children: [
          Positioned(
            left: left,
            top: top.toDouble(),
            width: width,
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: GlassSurface(
                radius: 24,
                child: Material(
                  type: MaterialType.transparency,
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final entry in entries)
                          InkWell(
                            borderRadius: BorderRadius.circular(17),
                            onTap: () => Navigator.pop(context, entry.$1),
                            child: SizedBox(
                              height: 54,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                child: Row(
                                  children: [
                                    if (entry.$1 == 'sort')
                                      const SettingsIcon(
                                        type: SettingsIconType.sort,
                                      )
                                    else if (entry.$1 == 'uninstall')
                                      ConversationMenuIcon(
                                        type: ConversationMenuIconType.archive,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      )
                                    else if (entry.$1 == 'create')
                                      const SettingsIcon(
                                        type: SettingsIconType.add,
                                      )
                                    else if (entry.$1 == 'install')
                                      const SettingsIcon(
                                        type: SettingsIconType.skills,
                                      )
                                    else if (entry.$1 == 'permissions')
                                      const SettingsIcon(
                                        type: SettingsIconType.personalization,
                                      )
                                    else
                                      TaskActionIcon(entry.$1),
                                    const SizedBox(width: 13),
                                    Text(
                                      entry.$2,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: entry.$1 == 'delete'
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.error
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
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
        ],
      );
    },
  );
}
