import 'dart:convert';
import 'package:flutter/material.dart';
import 'settings_icon.dart';

/// Uses the surrounding tool activity card; no separate task-mode UI.
class PrivateTaskHistory extends StatelessWidget {
  const PrivateTaskHistory({super.key, required this.resultJson});
  final String resultJson;

  @override
  Widget build(BuildContext context) {
    final task = (jsonDecode(resultJson) as Map)['task'] as Map;
    final colors = Theme.of(context).colorScheme;
    final status = switch (task['status']) {
      'active' => '进行中',
      'complete' => '已完成',
      'paused' => '已暂停',
      'blocked' => '等待补充',
      'cancelled' => '已取消',
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
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              '$status · ${task['completionCriteria']}',
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
          ],
          if ((task['reason'] as String? ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              task['reason'] as String,
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
          ],
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
          if (task.isEmpty)
            Text('暂无目标或计划', style: TextStyle(color: colors.onSurfaceVariant)),
        ],
      ),
    );
  }
}
