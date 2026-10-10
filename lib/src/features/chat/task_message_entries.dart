import 'package:flutter/widgets.dart';

import '../../domain/agent_models.dart';
import 'chat_message_spacing.dart';
import 'chat_timeline_entry.dart';
import 'group_message_heading.dart';
import 'subagent_tool_activity.dart';

List<ChatTimelineEntry> taskMessageEntries(
  AgentTaskSummary? summary, {
  required String messageId,
  required bool chatBubbles,
  required bool isGroup,
}) => [
  if (summary != null)
    for (final (index, activity) in summary.activities.indexed)
      if (activity.toolName == 'runTask')
        ChatTimelineEntry(
          'task-entry:$messageId:$index',
          (_) => taskMessageLayout(
            chatBubbles: chatBubbles,
            isGroup: isGroup,
            child: SubagentToolActivity(
              organizedTask: true,
              status: activity.status!,
              requestJson: activity.requestJson,
              resultJson: activity.resultJson,
            ),
          ),
        ),
];

Widget taskMessageLayout({
  required Widget child,
  required bool chatBubbles,
  required bool isGroup,
}) => ChatMessageSpacing(
  child: Padding(
    padding: EdgeInsets.only(
      left: chatBubbles
          ? GroupMessageHeading.leftInset +
                (isGroup
                    ? GroupMessageHeading.avatarSize +
                          GroupMessageHeading.avatarGap
                    : 0)
          : 18,
      right: chatBubbles ? GroupMessageHeading.rightInset : 18,
    ),
    child: child,
  ),
);
