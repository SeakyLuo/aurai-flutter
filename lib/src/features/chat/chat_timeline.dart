import '../../domain/tool_activity_groups.dart';
import 'tool_activity_group.dart';
import 'task_elapsed.dart';
import 'package:flutter/material.dart';

import '../../domain/agent_models.dart';
import '../../domain/web_sources.dart';
import 'chat_controller.dart';
import 'message_item.dart';
import 'message_time.dart';
import 'tool_activity_view.dart';

class ChatTimelineEntry {
  const ChatTimelineEntry(this.id, this.builder);
  final String id;
  final WidgetBuilder builder;
}

List<ChatTimelineEntry> buildChatTimeline(
  ChatController controller, {
  required Future<void> Function(AgentMessage) onEdit,
  String? beforeMessageId,
  bool allowEditing = true,
}) {
  final conversation = controller.activeConversation;
  final watch = conversation.executionWatch;
  final showElapsed =
      watch != null &&
      conversation.hasExecutionProcess &&
      (watch.isRunning || conversation.runState == ChatRunState.failed) &&
      !controller.messages.any(
        (message) =>
            message.runId == conversation.activeRunId &&
            message.taskSummary != null,
      );
  final hiddenIds = {
    for (final message in controller.messages)
      if (message.taskSummary != null)
        ...message.taskSummary!.intermediateMessageIds,
  };
  final toolsByMessage = <String, List<ChatTimelineEntry>>{};
  final liveSteps = controller.activeConversation.liveToolSteps;
  final liveSources = webSourcesFromSteps(liveSteps.map((entry) => entry.step));
  final groups = toolActivityGroups([
    for (final entry in liveSteps)
      entry.step.toolName == 'askUser'
          ? null
          : '${entry.afterMessageId}:${entry.step.toolName}',
  ]);
  for (final group in groups) {
    final entry = liveSteps[group.start];
    final storageId = 'tool:${conversation.activeRunId}:${group.start}';
    toolsByMessage
        .putIfAbsent(entry.afterMessageId, () => [])
        .add(
          ChatTimelineEntry(
            storageId,
            (_) => group.end - group.start == 1
                ? _ToolActivity(storageId: storageId, step: entry.step)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                    child: ToolActivityGroup(
                      key: ValueKey(storageId),
                      storageId: storageId,
                      toolName: entry.step.toolName,
                      statuses: [
                        for (var i = group.start; i < group.end; i++)
                          liveSteps[i].step.status,
                      ],
                      children: [
                        for (var i = group.start; i < group.end; i++)
                          _ToolActivity(
                            storageId: 'tool:${conversation.activeRunId}:$i',
                            step: liveSteps[i].step,
                            grouped: true,
                          ),
                      ],
                    ),
                  ),
          ),
        );
  }
  final visibleMessages = controller.messages
      .where((message) => !hiddenIds.contains(message.id))
      .toList();
  final end = beforeMessageId == null
      ? visibleMessages.length
      : visibleMessages.indexWhere((message) => message.id == beforeMessageId);
  return [
    for (final (index, message)
        in visibleMessages
            .take(end + (beforeMessageId == null ? 0 : 1))
            .indexed) ...[
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
      if (message.id != beforeMessageId)
        ChatTimelineEntry(
          message.id,
          (context) => MessageItem(
            key: ValueKey(message.id),
            message: message,
            availableSources:
                message.runId != null &&
                    message.runId == conversation.activeRunId
                ? liveSources
                : const {},
            onEdit: allowEditing ? onEdit : null,
            streaming:
                controller.streamingMessageId == message.id ||
                (controller.isBusy &&
                    message.runId == controller.activeConversation.activeRunId),
          ),
        ),
      if (showElapsed &&
          message.id == conversation.executionUserMessageId &&
          message.id != beforeMessageId)
        ChatTimelineEntry(
          'elapsed:${conversation.activeRunId}',
          (_) => TaskElapsed(
            key: ValueKey(conversation.activeRunId),
            watch: watch,
            restoredElapsed: conversation.restoredExecutionElapsed,
            failed: conversation.runState == ChatRunState.failed,
          ),
        ),
      if (message.id != beforeMessageId) ...?toolsByMessage[message.id],
    ],
  ];
}

Map<String, String> chatSummaryOwners(ChatController controller) => {
  for (final message in controller.messages) 'time:${message.id}': message.id,
  for (final message in controller.messages)
    if (message.taskSummary != null) ...{
      'elapsed:${message.runId}': message.id,
      for (final id in message.taskSummary!.intermediateMessageIds)
        id: message.id,
      for (var i = 0; i < message.taskSummary!.activities.length; i++)
        'tool:${message.runId}:$i': message.id,
      if (message.runId == controller.activeConversation.activeRunId)
        'progress:${controller.activeConversation.id}': message.id,
    },
};

class _ToolActivity extends StatelessWidget {
  const _ToolActivity({
    required this.step,
    required this.storageId,
    this.grouped = false,
  });
  final bool grouped;
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
      padding: grouped
          ? const EdgeInsets.symmetric(vertical: 5)
          : const EdgeInsets.fromLTRB(18, 4, 18, 8),
      child: ToolActivityView(
        toolName: step.toolName,
        storageId: storageId,
        title: '$prefix${step.title}',
        status: step.status,
        requestJson: step.requestJson,
        resultJson: step.resultJson,
      ),
    );
  }
}
