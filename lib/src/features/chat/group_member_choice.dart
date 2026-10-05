import 'package:flutter/material.dart';

import '../../domain/message_sender.dart';
import 'member_avatar.dart';
import 'settings_icon.dart';
import 'member_selection_mark.dart';

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
                MemberSelectionMark(selected: selected),
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
