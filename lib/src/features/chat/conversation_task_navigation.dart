import '../../app/glass_notice.dart';
import 'package:flutter/material.dart';
import '../../scheduling/task_detail_page.dart';
import '../../scheduling/task_filter_menu.dart';
import 'chat_controller.dart';

List<Map<String, Object?>> conversationTasks(
  ChatController controller,
  String conversationId, {
  String? originTaskId,
}) => controller.scheduledTasks.tasks
    .where(
      (task) =>
          task['sourceConversationId'] == conversationId ||
          task['conversationId'] == conversationId ||
          task['id'] == originTaskId,
    )
    .toList();

Future<void> openConversationTask(
  BuildContext context,
  ChatController controller,
  String conversationId, {
  String? originTaskId,
}) async {
  final tasks = conversationTasks(
    controller,
    conversationId,
    originTaskId: originTaskId,
  );
  if (tasks.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showGlassSnackBar(const SnackBar(content: Text('关联任务已删除')));
    return;
  }
  String? id;
  if (tasks.length == 1) {
    id = tasks.single['id'] as String;
  } else {
    final box = context.findRenderObject()! as RenderBox;
    id = await showTaskChoiceMenu(
      context,
      anchor: box.localToGlobal(Offset.zero) & box.size,
      selected: originTaskId ?? '',
      label: '查看任务',
      choices: [
        for (final task in tasks)
          (value: task['id'] as String, label: task['title'] as String),
      ],
    );
  }
  if (!context.mounted || id == null) return;
  if (id == originTaskId) {
    Navigator.pop(context);
    return;
  }
  await Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => TaskDetailPage(
        controller: controller,
        id: id!,
        returnConversationId: controller.activeConversation.id == conversationId
            ? conversationId
            : null,
      ),
    ),
  );
}
