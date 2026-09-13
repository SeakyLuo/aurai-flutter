import 'package:flutter/material.dart';
import '../../domain/message_sender.dart';
import 'member_avatar.dart';

class GroupMessageHeading extends StatelessWidget {
  const GroupMessageHeading({
    super.key,
    required this.sender,
    required this.child,
    required this.onOpenProfile,
  });
  final MessageSender sender;
  final Widget child;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: '查看${sender.name}的资料',
          child: InkWell(
            onTap: onOpenProfile,
            borderRadius: BorderRadius.circular(18),
            child: MemberAvatar(sender: sender, size: 36),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sender.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              child,
            ],
          ),
        ),
      ],
    ),
  );
}
