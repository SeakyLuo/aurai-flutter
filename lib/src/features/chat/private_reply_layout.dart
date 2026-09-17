import '../../domain/agent_models.dart';
import '../../domain/message_sender.dart';

/// Cards retain their message identities while sharing one private reply shell.
class PrivateReplyPart {
  const PrivateReplyPart({
    required this.first,
    required this.last,
    required this.copyText,
    required this.summary,
  });

  final bool first;
  final bool last;
  final String copyText;
  final AgentTaskSummary? summary;
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
    var end = start + 1;
    while (end < messages.length) {
      final next = messages[end];
      if (next.runId != first.runId ||
          next.senderId != first.senderId ||
          next.role != AgentMessageRole.assistant ||
          next.isSystem ||
          next.isFailure)
        break;
      end++;
    }
    AgentTaskSummary? summary;
    final text = <String>[];
    for (var i = start; i < end; i++) {
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
    final process = summary == null
        ? null
        : AgentTaskSummary(
            elapsedMilliseconds: summary.elapsedMilliseconds,
            stopped: summary.stopped,
            intermediateMessageIds: const [],
            activities: summary.activities
                .where((activity) => activity.toolName != null)
                .toList(),
          );
    final copyText = text.where((part) => part.isNotEmpty).join('\n\n');
    for (var i = start; i < end; i++) {
      result[messages[i].id] = PrivateReplyPart(
        first: i == start,
        last: i == end - 1,
        copyText: copyText,
        summary: i == start ? process : null,
      );
    }
    start = end;
  }
  return result;
}
