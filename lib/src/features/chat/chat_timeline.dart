import 'package:flutter/material.dart';

import '../../domain/agent_models.dart';
import 'chat_controller.dart';
import 'message_item.dart';
import 'message_editor.dart';
import 'message_time.dart';
import 'tool_activity_view.dart';

class ChatTimelineEntry {
  const ChatTimelineEntry(this.id, this.builder);
  final String id;
  final WidgetBuilder builder;
}

List<ChatTimelineEntry> buildChatTimeline(
  ChatController controller, {
  required bool Function() preparingGoal,
  required Future<void> Function() continueReply,
}) {
  final hiddenIds = {
    for (final message in controller.messages)
      if (message.taskSummary != null)
        ...message.taskSummary!.intermediateMessageIds,
  };
  final toolsByMessage = <String, List<ChatTimelineEntry>>{};
  final liveSteps = controller.activeConversation.liveToolSteps;
  for (var i = 0; i < liveSteps.length; i++) {
    final entry = liveSteps[i];
    toolsByMessage
        .putIfAbsent(entry.afterMessageId, () => [])
        .add(
          ChatTimelineEntry(
            'tool:${controller.activeConversation.activeRunId}:$i',
            (_) => _ToolActivity(
              storageId: 'tool:${controller.activeConversation.activeRunId}:$i',
              step: entry.step,
            ),
          ),
        );
  }
  final visibleMessages = controller.messages
      .where((message) => !hiddenIds.contains(message.id))
      .toList();
  return [
    for (final (index, message) in visibleMessages.indexed) ...[
      if (index > 0 &&
          message.createdAt.difference(visibleMessages[index - 1].createdAt) >
              const Duration(minutes: 30))
        ChatTimelineEntry(
          'time:${message.id}',
          (context) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Center(
              child: Text(
                messageTime(message.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ChatTimelineEntry(
        message.id,
        (context) => MessageItem(
          key: ValueKey(message.id),
          message: message,
          onEdit: (message) => editChatMessage(
            context,
            controller: controller,
            message: message,
            preparingGoal: preparingGoal,
            continueReply: continueReply,
          ),
          streaming:
              controller.streamingMessageId == message.id ||
              (controller.isBusy &&
                  message.runId == controller.activeConversation.activeRunId),
        ),
      ),
      ...?toolsByMessage[message.id],
    ],
  ];
}

Map<String, String> chatSummaryOwners(ChatController controller) => {
  for (final message in controller.messages) 'time:${message.id}': message.id,
  for (final message in controller.messages)
    if (message.taskSummary != null) ...{
      for (final id in message.taskSummary!.intermediateMessageIds)
        id: message.id,
      for (var i = 0; i < message.taskSummary!.activities.length; i++)
        'tool:${message.runId}:$i': message.id,
      if (message.runId == controller.activeConversation.activeRunId)
        'progress:${controller.activeConversation.id}': message.id,
    },
};

class _ToolActivity extends StatelessWidget {
  const _ToolActivity({required this.step, required this.storageId});
  final String storageId;

  final AgentStep step;

  @override
  Widget build(BuildContext context) {
    final prefix = switch (step.status) {
      AgentStepStatus.running => '正在',
      AgentStepStatus.completed => '已完成：',
      AgentStepStatus.failed => '未完成：',
      AgentStepStatus.cancelled => '已停止：',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
      child: ToolActivityView(
        storageId: storageId,
        title: '$prefix${step.title}',
        status: step.status,
        requestJson: step.requestJson,
        resultJson: step.resultJson,
      ),
    );
  }
}
