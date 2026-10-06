import 'profile_navigation.dart';
import 'package:flutter/material.dart';
import '../../domain/message_sender.dart';
import 'ai_contact_page.dart';
import 'chat_controller.dart';
import 'member_avatar.dart';
import 'personal_info_page.dart';

Future<void> openMemberProfile(
  BuildContext context, {
  required ChatController controller,
  required MessageSender sender,
  String? groupId,
}) => openProfileRoute(
  context,
  MaterialPageRoute<void>(
    builder: (_) => sender.id == MessageSender.localUser.id
        ? PersonalInfoPage(memory: controller.memory)
        : AiContactPage(
            controller: controller,
            senderId: sender.id,
            groupId: groupId,
          ),
  ),
);

class MemberProfileAvatar extends StatelessWidget {
  const MemberProfileAvatar({
    super.key,
    required this.controller,
    required this.sender,
    this.groupId,
    this.size = 36,
    this.onTap,
  });
  final ChatController controller;
  final MessageSender sender;
  final String? groupId;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '查看${sender.displayName}的资料',
    child: InkWell(
      borderRadius: BorderRadius.circular(size / 2),
      onTap:
          onTap ??
          () => openMemberProfile(
            context,
            controller: controller,
            sender: sender,
            groupId: groupId,
          ),
      child: MemberAvatar(sender: sender, size: size),
    ),
  );
}
