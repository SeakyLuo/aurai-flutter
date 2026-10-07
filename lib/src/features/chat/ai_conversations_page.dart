import 'package:flutter/material.dart';
import '../../domain/ai_profile.dart';
import 'chat_controller.dart';
import 'recent_chats_page.dart';

class AiConversationsPage extends StatelessWidget {
  const AiConversationsPage({
    super.key,
    required this.controller,
    required this.profile,
  });
  final ChatController controller;
  final AiProfile profile;
  @override
  Widget build(BuildContext context) =>
      RecentChatsPage(controller: controller, profile: profile);
}
