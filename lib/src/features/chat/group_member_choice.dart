import 'package:flutter/material.dart';

import 'settings_appearance.dart';
import 'settings_icon.dart';

class GroupMemberChoice extends StatelessWidget {
  const GroupMemberChoice({
    super.key,
    required this.selected,
    required this.title,
    required this.onTap,
    this.isAurai = false,
  });

  final bool selected;
  final String title;
  final VoidCallback? onTap;
  final bool isAurai;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      checked: selected,
      enabled: onTap != null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 22,
                  height: 22,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? colors.onSurface : Colors.transparent,
                    border: Border.all(
                      color: selected ? colors.onSurface : colors.outline,
                      width: 1.4,
                    ),
                  ),
                  child: selected
                      ? SettingsIcon(
                          type: SettingsIconType.check,
                          color: colors.surface,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: settingsFieldColor(context),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.center,
                  child: isAurai
                      ? Image.asset(
                          'assets/branding/app_logo.png',
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                        )
                      : Text(
                          title.characters.first,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
