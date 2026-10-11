import '../../domain/agent_models.dart';

/// Keep execution summaries ahead of notices emitted while the run was working.
/// Message records themselves retain their chronological order.
Map<String, String> taskSummaryAnchors(
  List<AgentMessage> messages,
  List<AgentMessage> visibleMessages,
  Map<String, AgentTaskSummary> summaries,
) {
  final starts = <String, DateTime>{};
  void include(String runId, DateTime time) {
    final previous = starts[runId];
    if (previous == null || time.isBefore(previous)) starts[runId] = time;
  }

  final byId = {for (final message in messages) message.id: message};
  for (final message in messages) {
    if (message.runId case final runId?) include(runId, message.createdAt);
  }
  for (final entry in summaries.entries) {
    final runId = byId[entry.key]!.runId!;
    for (final activity in entry.value.activities) {
      if (activity.startedAt case final time?) include(runId, time);
    }
  }
  final anchors = <String, String>{};
  for (final entry in summaries.entries) {
    final owner = byId[entry.key]!;
    final start = starts[owner.runId]!;
    for (final message in visibleMessages) {
      if (message.id == owner.id) break;
      if (message.isSystem && !message.createdAt.isBefore(start)) {
        anchors[owner.id] = message.id;
        break;
      }
    }
  }
  return anchors;
}
