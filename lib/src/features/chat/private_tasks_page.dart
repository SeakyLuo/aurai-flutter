import 'package:flutter/material.dart';

import '../../storage/private_task_state.dart';
import 'chat_controller.dart';
import 'group_tasks_page.dart';

class PrivateTasksPage extends StatelessWidget {
  const PrivateTasksPage({
    super.key,
    required this.controller,
    required this.conversationId,
    required this.senderId,
    this.originTaskId,
  });
  final ChatController controller;
  final String conversationId, senderId;
  final String? originTaskId;

  @override
  Widget build(BuildContext context) => GroupTasksPage(
    controller: controller,
    conversationId: conversationId,
    originTaskId: originTaskId,
    privateStore: PrivateTaskState(
      controller.groupStore.database,
      conversationId,
      senderId,
    ),
  );
}
