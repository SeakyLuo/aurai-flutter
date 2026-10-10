import 'package:flutter/material.dart';
import '../../domain/agent_models.dart';
import 'tool_activity_view.dart';
import 'task_message_entries.dart';

class TimelineToolActivity extends StatelessWidget {
  const TimelineToolActivity({
    required this.step,
    required this.storageId,
    this.grouped = false,
    this.senderName,
    this.chatBubbles = false,
    this.isGroup = false,
  });
  final bool grouped;
  final bool chatBubbles, isGroup;
  final String? senderName;
  final String storageId;

  final AgentStep step;

  @override
  Widget build(BuildContext context) {
    if (step.toolName == 'runTask') {
      return taskMessageLayout(
        chatBubbles: chatBubbles,
        isGroup: isGroup,
        child: ToolActivityView(
          toolName: step.toolName,
          storageId: storageId,
          title: step.title,
          status: step.status,
          requestJson: step.requestJson,
          resultJson: step.resultJson,
        ),
      );
    }
    return Padding(
      padding: grouped
          ? const EdgeInsets.symmetric(vertical: 5)
          : const EdgeInsets.fromLTRB(18, 4, 18, 8),
      child: ToolActivityView(
        callId: step.callId,
        showFileChanges: !grouped,
        toolName: step.toolName,
        storageId: storageId,
        title: _toolActivityTitle(step, senderName),
        startedAt: step.startedAt,
        finishedAt: step.finishedAt,
        status: step.status,
        requestJson: step.requestJson,
        resultJson: step.resultJson,
      ),
    );
  }
}

String _toolActivityTitle(AgentStep step, String? senderName) {
  final prefix = switch (step.status) {
    AgentStepStatus.running => '正在',
    AgentStepStatus.completed => '已完成：',
    AgentStepStatus.failed => '未完成：',
    AgentStepStatus.cancelled => '已停止：',
  };
  return '${senderName == null ? '' : '$senderName '}$prefix${step.title}';
}
