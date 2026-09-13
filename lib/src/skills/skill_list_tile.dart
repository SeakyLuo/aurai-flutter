import 'package:flutter/material.dart';

import '../features/chat/settings_appearance.dart';
import 'skill_icon.dart';
import 'skill_store.dart';

class SkillListTile extends StatelessWidget {
  const SkillListTile({
    super.key,
    required this.skill,
    required this.onTap,
    this.titleTrailing,
    this.onLongPressStart,
    this.showDisabled = false,
  });

  final SavedSkill skill;
  final VoidCallback onTap;
  final Widget? titleTrailing;
  final GestureLongPressStartCallback? onLongPressStart;
  final bool showDisabled;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onLongPressStart: onLongPressStart,
    child: Material(
      color: settingsFieldColor(context),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),
        title: Row(
          children: [
            SkillIcon(skill.icon),
            const SizedBox(width: 10),
            Expanded(child: Text(skill.name)),
            if (titleTrailing != null) ...[
              const SizedBox(width: 8),
              titleTrailing!,
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            showDisabled && !skill.enabled
                ? '已停用 · ${skill.description}'
                : skill.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        onTap: onTap,
      ),
    ),
  );
}
