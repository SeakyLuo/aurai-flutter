import 'dart:convert';
import 'package:flutter/material.dart';
import 'settings_icon.dart';

/// Uses the surrounding tool activity card; no separate task-mode UI.
class PrivateTaskHistory extends StatelessWidget {
  const PrivateTaskHistory({
    super.key,
    required this.resultJson,
    this.showGoalMetadata = true,
  });
  final String resultJson;
  final bool showGoalMetadata;

  @override
  Widget build(BuildContext context) {
    final result = jsonDecode(resultJson) as Map;
    final task = result['task'] as Map;
    final isTaskList = result['kind'] == 'taskList';
    final colors = Theme.of(context).colorScheme;
    final status = switch (task['status']) {
      'active' => null,
      'complete' => '已完成',
      'paused' => '已暂停',
      'blocked' => '目标已停滞',
      'budget_limited' => '目标预算已用完',
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (task['objective'] != null) ...[
            Text(
              task['objective'] as String,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
            if (showGoalMetadata && status != null) ...[
              const SizedBox(height: 6),
              Text(
                status,
                style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
              ),
            ],
          ],
          if (task['tokenBudget'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Token 预算',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${task['tokenBudget']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          if (showGoalMetadata &&
              (task['reason'] as String? ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              task['reason'] as String,
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
          ],
          if ((task['explanation'] as String? ?? '').isNotEmpty)
            Text(
              task['explanation'] as String,
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
          for (final step in task['steps'] as List? ?? const [])
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox.square(
                    dimension: 18,
                    child: step['status'] == 'completed'
                        ? SettingsIcon(
                            type: SettingsIconType.check,
                            color: colors.onSurfaceVariant,
                          )
                        : Center(
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: step['status'] == 'in_progress'
                                    ? colors.onSurface
                                    : colors.outlineVariant,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      step['step'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        color: step['status'] == 'in_progress'
                            ? colors.onSurface
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (isTaskList
              ? (task['steps'] as List? ?? const []).isEmpty
              : task.isEmpty)
            Text(
              isTaskList ? '暂无计划' : '暂无目标',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
