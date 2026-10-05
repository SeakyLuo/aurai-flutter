import 'package:flutter/material.dart';

import '../../storage/development_projects.dart';
import 'message_time.dart';
import 'conversation_status_dot.dart';
import 'project_icon.dart';
import 'settings_appearance.dart';

class ProjectListTile extends StatelessWidget {
  const ProjectListTile({
    super.key,
    required this.project,
    required this.onTap,
    this.prefix,
    this.trailing,
    this.unread = false,
  });

  final DevelopmentProject project;
  final VoidCallback onTap;
  final Widget? prefix;
  final Widget? trailing;
  final bool unread;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(22),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      minTileHeight: 64,
      minVerticalPadding: 8,
      horizontalTitleGap: 12,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      leading: SizedBox(
        width: prefix == null ? 48 : 84,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (prefix != null) ...[prefix!, const SizedBox(width: 14)],
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: settingsFieldColor(context),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(
                    child: ProjectIcon(
                      icon: project.icon,
                      color: project.iconColor,
                      size: 24,
                    ),
                  ),
                ),
                if (unread)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Semantics(
                      label: '有未读消息',
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: unreadDotColor,
                          border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      title: Text(project.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(conversationMessageTime(project.updatedAt)),
      trailing: trailing,
      onTap: onTap,
    ),
  );
}
