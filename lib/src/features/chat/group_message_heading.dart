import 'group_nickname_visibility.dart';
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
    this.showAvatar = true,
    this.groupId,
    this.trailingInset = rightInset,
  });
  static const leftInset = 12.0;
  static const rightInset = 28.0;
  static const restrictedRightInset = 4.0;
  static const avatarSize = 36.0;
  static const avatarGap = 8.0;
  static const contentInset = leftInset + avatarSize + avatarGap + rightInset;
  static const ownContentInset = leftInset + avatarSize + avatarGap + 18;

  final bool showName;
  final bool showAvatar;
  final double trailingInset;
  final String? groupId;
  final MessageSender sender;
  final Widget child;
  final VoidCallback onOpenProfile;
  final VoidCallback? onMention;

  @override
  Widget build(BuildContext context) => groupId == null
      ? _build(context, showName)
      : GroupNicknameVisibility(
          groupId: groupId!,
          builder: (context, visible) => _build(context, showName && visible),
        );

  Widget _build(BuildContext context, bool nameVisible) => Padding(
    padding: EdgeInsets.fromLTRB(leftInset, 0, trailingInset, 0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showAvatar)
          Padding(
            padding: EdgeInsets.only(
              top:
                  nameVisible ||
                      InteractivePageScope.of(context)?.control != null
                  ? 0
                  : 12 +
                        MediaQuery.textScalerOf(context).scale(15) * 1.4 / 2 -
                        avatarSize / 2,
            ),
            child: Semantics(
              button: true,
              label: '查看${sender.displayName}的资料',
              child: InkWell(
                onTap: onOpenProfile,
                onLongPress: onMention,
                borderRadius: BorderRadius.circular(18),
                child: MemberAvatar(sender: sender, size: avatarSize),
              ),
            ),
          ),
        if (showAvatar) const SizedBox(width: avatarGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (nameVisible ||
                  InteractivePageScope.of(context)?.control != null)
                Row(
                  children: [
                    Expanded(
                      child: !nameVisible
                          ? const SizedBox.shrink()
                          : Text(
                              sender.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                    ),
                    if (InteractivePageScope.of(context)?.control
                        case final control?)
                      control,
                  ],
                ),
              if (nameVisible ||
                  InteractivePageScope.of(context)?.control != null)
                const SizedBox(height: 6),
              child,
            ],
          ),
        ),
      ],
    ),
  );
}
