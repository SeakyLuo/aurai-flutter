import 'package:flutter/material.dart';

import 'settings_icon.dart';

class VisibilityOptionTile extends StatelessWidget {
  const VisibilityOptionTile({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.opensMembers = false,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final bool opensMembers;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    inMutuallyExclusiveGroup: true,
    child: ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: SizedBox.square(
        dimension: 24,
        child: selected
            ? DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: SettingsIcon(
                    type: SettingsIconType.check,
                    color: Theme.of(context).colorScheme.surface,
                  ),
                ),
              )
            : null,
      ),
      title: Text(title),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: opensMembers
          ? const SettingsIcon(type: SettingsIconType.chevron)
          : null,
      onTap: onTap,
    ),
  );
}
