import 'package:flutter/material.dart';
import '../../domain/message_sender.dart';
import 'group_avatar.dart';

class GroupPickerTile extends StatelessWidget {
  const GroupPickerTile({
    super.key,
    required this.title,
    required this.groupId,
    required this.members,
    required this.onTap,
    this.prefix,
  });
  final String title;
  final String groupId;
  final List<MessageSender> members;
  final VoidCallback onTap;
  final Widget? prefix;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
      horizontalTitleGap: 12,
      minTileHeight: 72,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 16),
      ),
      leading: SizedBox(
        width: prefix == null ? 40 : 76,
        child: Row(
          children: [
            if (prefix != null) ...[prefix!, const SizedBox(width: 14)],
            GroupAvatar(groupId: groupId, members: members, size: 40),
          ],
        ),
      ),
      onTap: onTap,
    ),
  );
}
