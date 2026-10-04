import 'profile_navigation.dart';
import 'package:flutter/material.dart';
import '../../domain/message_sender.dart';
import 'ai_contact_page.dart';
import 'chat_controller.dart';
import 'member_avatar.dart';
import 'personal_info_page.dart';

class MemberProfileAvatar extends StatelessWidget {
  const MemberProfileAvatar({
    super.key,
    required this.controller,
    required this.sender,
    this.groupId,
    this.size = 36,
  });
  final ChatController controller;
  final MessageSender sender;
  final String? groupId;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '查看${sender.name}的资料',
    child: InkWell(
      borderRadius: BorderRadius.circular(size / 2),
      onTap: () => openProfileRoute(
        context,
        MaterialPageRoute(
          builder: (_) => sender.id == MessageSender.localUser.id
              ? PersonalInfoPage(memory: controller.memory)
              : AiContactPage(
                  controller: controller,
                  senderId: sender.id,
                  groupId: groupId,
                ),
        ),
      ),
      child: MemberAvatar(sender: sender, size: size),
    ),
  );
}
