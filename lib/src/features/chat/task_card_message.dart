import 'package:flutter/material.dart';

import '../../app/ui_action.dart';
import '../../domain/agent_models.dart';
import 'image_action_scope.dart';
import 'task_conversation_navigation.dart';
import 'task_entry_card.dart';

class TaskCardMessage extends StatelessWidget {
  const TaskCardMessage({
    super.key,
    required this.message,
    required this.groupBubble,
    required this.onLongPress,
    required this.wrapContent,
  });

  final AgentMessage message;
  final bool groupBubble;
  final VoidCallback onLongPress;
  final Widget Function(Widget) wrapContent;

  @override
  Widget build(BuildContext context) {
    final card = message.messageMetadata!.participation['_taskCard'] as Map;
    final status = AgentStepStatus.values.byName(card['status'] as String);
    final title = card['title'] as String;
    final label = switch (status) {
      AgentStepStatus.running => '执行中',
      AgentStepStatus.completed =>
        card['startExecution'] == false ? '已创建' : '已完成',
      AgentStepStatus.cancelled => '已停止',
      AgentStepStatus.failed => '未完成',
    };
    return Padding(
      padding: EdgeInsets.fromLTRB(
        groupBubble ? 0 : 18,
        groupBubble ? 0 : 12,
        groupBubble ? 0 : 18,
        groupBubble ? 0 : 24,
      ),
      child: wrapContent(
        GestureDetector(
          onLongPress: onLongPress,
          child: TaskEntryCard(
            title: title,
            description: card['description'] as String,
            status: label,
            failed: status == AgentStepStatus.failed,
            onTap: () async {
              await runUiAction(
                context,
                () => openTaskConversation(
                  context,
                  ImageActionScope.of(context),
                  card['taskId'] as String,
                  title: title,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
