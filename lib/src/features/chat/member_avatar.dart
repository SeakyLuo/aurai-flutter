import 'package:flutter/material.dart';
import '../../domain/message_sender.dart';
import '../../domain/avatar_style.dart';
import 'profile_avatar.dart';

class MemberAvatar extends StatelessWidget {
  const MemberAvatar({super.key, required this.sender, this.size = 36});
  final MessageSender sender;
  final double size;

  @override
  Widget build(BuildContext context) => ProfileAvatar(
    style: AvatarStyle(
      icon: sender.avatarIcon,
      color: sender.avatarColor,
      path: sender.avatarPath,
    ),
    name: sender.name,
    size: size,
  );
}
