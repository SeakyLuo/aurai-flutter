import 'package:flutter/material.dart';

import 'conversation_menu_icon.dart';
import 'settings_icon.dart';

class GroupAppsSection extends StatelessWidget {
  const GroupAppsSection({
    super.key,
    required this.onTasks,
    required this.onMarks,
    required this.onTools,
    required this.onSkills,
    this.title = '群应用',
  });
  final String title;
  final VoidCallback onTasks, onMarks, onTools, onSkills;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(title, style: const TextStyle(fontSize: 15)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _entry(
                context,
                '任务',
                SettingsIcon(
                  type: SettingsIconType.taskList,
                  color: colors.onSurfaceVariant,
                ),
                onTasks,
              ),
              _entry(
                context,
                '标记',
                SizedBox.square(
                  dimension: 24,
                  child: FittedBox(
                    child: ConversationMenuIcon(
                      type: ConversationMenuIconType.mark,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                onMarks,
              ),
              _entry(
                context,
                '工具',
                SettingsIcon(
                  type: SettingsIconType.tools,
                  color: colors.onSurfaceVariant,
                ),
                onTools,
              ),
              _entry(
                context,
                '技能',
                SettingsIcon(
                  type: SettingsIconType.skills,
                  color: colors.onSurfaceVariant,
                ),
                onSkills,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _entry(
    BuildContext context,
    String label,
    Widget icon,
    VoidCallback onTap,
  ) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Ink(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(child: icon),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
