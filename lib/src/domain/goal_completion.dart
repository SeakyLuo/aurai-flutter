import 'dart:convert';
import 'agent_models.dart';

/// Read the goal's own clock, rather than the duration of its final model run.
Duration? goalCompletionElapsed(AgentTaskSummary? summary) {
  if (summary == null || summary.stopped) return null;
  for (final activity in summary.activities.reversed) {
    if (activity.status != AgentStepStatus.completed ||
        !const {
          'createGoal',
          'updateGoal',
          'clearGoal',
        }.contains(activity.toolName)) {
      continue;
    }
    if (activity.toolName != 'updateGoal') return null;
    final result = jsonDecode(activity.resultJson!) as Map;
    final goal = result['task'] as Map;
    if (goal['status'] != 'complete') return null;
    return Duration(milliseconds: goal['elapsedMs'] as int);
  }
  return null;
}
