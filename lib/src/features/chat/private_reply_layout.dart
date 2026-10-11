import '../../domain/agent_models.dart';
import '../../domain/message_sender.dart';
import '../../domain/goal_completion.dart';

/// Cards retain their message identities while sharing one private reply shell.
class PrivateReplyPart {
  const PrivateReplyPart({
    required this.first,
    required this.last,
    required this.copyText,
    required this.summary,
    this.gitChanges,
    this.goalElapsed,
  });

  final bool first;
  final bool last;
  final String copyText;
  final AgentTaskSummary? summary;
  final ProjectGitTaskChanges? gitChanges;
  final Duration? goalElapsed;
}

Set<String> richReplyRuns(Iterable<AgentMessage> messages) => {
  for (final message in messages)
    if (message.runId != null &&
        (message.isRichReply ||
            message.interactive != null ||
            message.htmlGame != null ||
            (message.taskSummary?.activities.any(
                  (activity) =>
                      activity.status == AgentStepStatus.completed &&
                      const {
                        'sendInteractiveMessage',
                        'sendQuestion',
                        'sendPoll',
                        'sendQuestionnaire',
                        'sendHtmlMessage',
                      }.contains(activity.toolName),
                ) ??
                false)))
      message.runId!,
};

Map<String, PrivateReplyPart> privateReplyLayout(
  List<AgentMessage> messages,
  Set<String> richRuns,
) {
  final result = <String, PrivateReplyPart>{};
  var start = 0;
  while (start < messages.length) {
    final first = messages[start];
    if (first.role != AgentMessageRole.assistant ||
        first.isSystem ||
        first.isFailure ||
        !richRuns.contains(first.runId)) {
      start++;
      continue;
    }
    final replyIndices = [start];
    final programIds = {if (first.htmlGame != null) first.id};
    var end = start + 1;
    for (var index = end; index < messages.length; index++) {
      final next = messages[index];
      // Program notices retain their chronological slots, but do not split
      // their originating reply into separate headers and action footers.
      if (next.isSystem &&
          programIds.contains(
            next.messageMetadata?.participation['_programMessage'],
          )) {
        continue;
      }
      if (next.runId != first.runId ||
          next.senderId != first.senderId ||
          next.role != AgentMessageRole.assistant ||
          next.isSystem ||
          next.isFailure)
        break;
      replyIndices.add(index);
      if (next.htmlGame != null) programIds.add(next.id);
      end = index + 1;
    }
    AgentTaskSummary? summary;
    final text = <String>[];
    for (final i in replyIndices) {
      final message = messages[i];
      summary = message.taskSummary ?? summary;
      final card = message.interactive;
      if (card != null) {
        if (card.canView(MessageSender.localUser.id)) {
          final view = card.viewFor(MessageSender.localUser.id);
          text.add('${view.title}\n${view.body}'.trim());
        }
      } else {
        text.add(message.htmlGame?.title ?? message.text);
      }
    }
    final gitChanges = summary?.gitChanges;
    final process = summary == null
        ? null
        : AgentTaskSummary(
            elapsedMilliseconds: summary.elapsedMilliseconds,
            isTask: summary.isTask,
            stopped: summary.stopped,
            intermediateMessageIds: const [],
            activities: summary.activities
                .where(
                  (activity) =>
                      activity.toolName != null || activity.isReasoning,
                )
                .toList(),
          );
    final copyText = text.where((part) => part.isNotEmpty).join('\n\n');
    for (final i in replyIndices) {
      result[messages[i].id] = PrivateReplyPart(
        first: i == start,
        last: i == replyIndices.last,
        copyText: copyText,
        summary: i == start ? process : null,
        gitChanges: i == replyIndices.last ? gitChanges : null,
        goalElapsed: i == replyIndices.last
            ? goalCompletionElapsed(summary)
            : null,
      );
    }
    start = end;
  }
  return result;
}
