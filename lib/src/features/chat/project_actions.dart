import '../../platform/aurai_platform.dart';
import 'package:flutter/material.dart';

import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import '../../storage/development_projects.dart';
import 'chat_controller.dart';
import 'conversation_menu_icon.dart';
import 'delete_confirmation_dialog.dart';
import 'header_action_menu.dart';
import 'project_profile_page.dart';
import 'settings_icon.dart';

enum ProjectActionResult { changed, removed }

Future<ProjectActionResult?> showProjectActions(
  BuildContext anchorContext,
  ChatController controller,
  DevelopmentProject project, {
  bool? hasUnread,
  bool allowHomeShortcut = false,
}) async {
  final context = anchorContext;
  final unread =
      hasUnread ??
      (await controller.projects.unreadProjectIds([project.id])).isNotEmpty;
  if (!context.mounted) return null;
  final action = await showHeaderActionMenu(
    anchorContext,
    destructiveValues: const {'remove'},
    items: [
      (
        value: 'info',
        label: '项目信息',
        icon: const SettingsIcon(type: SettingsIconType.info),
      ),
      (
        value: 'pin',
        label: project.pinned ? '取消置顶' : '设为置顶',
        icon: ConversationMenuIcon(
          type: project.pinned
              ? ConversationMenuIconType.unpin
              : ConversationMenuIconType.pin,
        ),
      ),
      if (allowHomeShortcut)
        (
          value: 'shortcut',
          label: '添加到主屏幕',
          icon: const SettingsIcon(type: SettingsIconType.home),
        ),
      if (unread)
        (
          value: 'read',
          label: '全部标为已读',
          icon: const SettingsIcon(type: SettingsIconType.check),
        ),
      (
        value: 'remove',
        label: '移除项目',
        icon: ConversationMenuIcon(
          type: ConversationMenuIconType.delete,
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    ],
  );
  if (!context.mounted || action == null) return null;
  try {
    switch (action) {
      case 'info':
        final latest = await controller.projects.read(project.id);
        final removed = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ProjectProfilePage(controller: controller, project: latest),
          ),
        );
        return removed == true
            ? ProjectActionResult.removed
            : ProjectActionResult.changed;
      case 'shortcut':
        final result = await AuraiPlatform.instance.deviceExtension(
          'pinProjectShortcut',
          {'projectId': project.id, 'name': project.name},
        );
        if (context.mounted)
          _notice(
            context,
            result['existing'] == true ? '主屏幕快捷方式已更新' : '已请求添加，请按桌面提示确认',
          );
        return null;
      case 'pin':
        await controller.setProjectPinned(project, !project.pinned);
        return ProjectActionResult.changed;
      case 'read':
        await controller.markProjectRead(project);
        if (context.mounted) _notice(context, '项目会话已全部标为已读');
        return ProjectActionResult.changed;
      case 'remove':
        final confirmed = await showDialog<bool>(
          context: context,
          barrierColor: Colors.black.withValues(alpha: .24),
          builder: (_) => DeleteConfirmationDialog(
            title: '移除项目？',
            description: project.location == ProjectLocation.managed
                ? '项目中的会话会移回普通会话列表，Aurai 工作区内的项目文件会被删除，无法恢复。'
                : '项目中的会话会移回普通会话列表，手机文件夹及其中的内容不会删除。',
            confirmLabel: '移除',
          ),
        );
        if (confirmed != true) return null;
        await controller.removeProject(project);
        return ProjectActionResult.removed;
    }
  } on Object catch (error) {
    if (context.mounted) _notice(context, errorMessage(error));
  }
  return null;
}

void _notice(BuildContext context, String text) => ScaffoldMessenger.of(
  context,
).showGlassSnackBar(SnackBar(content: Text(text)));
