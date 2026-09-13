import 'package:flutter/material.dart';

import '../../domain/message_sender.dart';
import 'member_avatar.dart';
import 'settings_icon.dart';

class GroupMemberChoice extends StatelessWidget {
  const GroupMemberChoice({
    super.key,
    required this.selected,
    required this.sender,
    required this.onTap,
    this.onEdit,
  });

  final bool selected;
  final MessageSender sender;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

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
                Expanded(
                  child: InkWell(
                    onTap: onEdit,
                    borderRadius: BorderRadius.circular(12),
                    child: Row(
                      children: [
                        MemberAvatar(sender: sender),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            sender.name,
                            style: const TextStyle(fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (onEdit != null)
                          const SettingsIcon(type: SettingsIconType.chevron),
                      ],
                    ),
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
