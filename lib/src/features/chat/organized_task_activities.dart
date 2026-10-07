import 'package:flutter/material.dart';
import '../../domain/agent_models.dart';
import 'subagent_tool_activity.dart';

class OrganizedTaskActivities extends StatelessWidget {
  const OrganizedTaskActivities({super.key, required this.summary});
  final AgentTaskSummary summary;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final activity in summary.activities)
        if (activity.toolName == 'runTask')
          SubagentToolActivity(
            organizedTask: true,
            status: activity.status!,
            requestJson: activity.requestJson,
            resultJson: activity.resultJson,
          ),
    ],
  );
}
