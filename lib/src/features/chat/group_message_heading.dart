import 'interactive_message_paging.dart';
import 'package:flutter/material.dart';
import '../../domain/message_sender.dart';
import 'member_avatar.dart';

class GroupMessageHeading extends StatelessWidget {
  const GroupMessageHeading({
    super.key,
    required this.sender,
    required this.child,
    required this.onOpenProfile,
    this.onMention,
    this.showName = true,
  });
  static const leftInset = 12.0;
  static const rightInset = 18.0;
  static const avatarSize = 36.0;
  static const avatarGap = 8.0;
  static const contentInset = leftInset + avatarSize + avatarGap + rightInset;

  final bool showName;
  final MessageSender sender;
  final Widget child;
  final VoidCallback onOpenProfile;
  final VoidCallback? onMention;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(leftInset, 0, rightInset, 0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: '查看${sender.name}的资料',
          child: InkWell(
            onTap: onOpenProfile,
            onLongPress: onMention,
            borderRadius: BorderRadius.circular(18),
            child: MemberAvatar(sender: sender, size: avatarSize),
          ),
        ),
        const SizedBox(width: avatarGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showName)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        sender.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (InteractivePageScope.of(context)?.control
                        case final control?)
                      control,
                  ],
                ),
              child,
            ],
          ),
        ),
      ],
    ),
  );
}
