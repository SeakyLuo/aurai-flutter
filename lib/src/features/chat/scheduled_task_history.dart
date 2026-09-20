import '../../app/glass_notice.dart';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../domain/agent_models.dart';
import '../../app/global_ui.dart';
import '../../scheduling/scheduled_tasks.dart';

String? scheduledTaskOperation(String? name, String? requestJson) {
  if (name == 'scheduledTask') {
    if (requestJson == null) return null;
    final request = jsonDecode(requestJson) as Map;
    return request['action'] == 'save'
        ? (request['id'] == null ? 'create' : 'update')
        : request['action'] as String?;
  }
  return switch (name) {
    'createScheduledTask' => 'create',
    'updateScheduledTask' => 'update',
    'listScheduledTasks' => 'list',
    'pauseScheduledTask' => 'pause',
    'resumeScheduledTask' => 'resume',
    'deleteScheduledTask' => 'delete',
    _ => null,
  };
}

class ScheduledTaskHistory extends StatelessWidget {
  const ScheduledTaskHistory({
    super.key,
    required this.status,
    required this.operation,
    required this.requestJson,
    required this.resultJson,
  });

  final AgentStepStatus status;
  final String operation;
  final String? requestJson;
  final String? resultJson;

  @override
  Widget build(BuildContext context) {
    final output = resultJson == null ? null : jsonDecode(resultJson!) as Map;
    final colors = Theme.of(context).colorScheme;
    Widget content;
    if (status == AgentStepStatus.failed) {
      content = Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => ScaffoldMessenger.of(context).showGlassSnackBar(
            SnackBar(
              content: Text(
                (output?['message'] ?? output?['error'] ?? '此记录未保存未完成原因')
                    as String,
              ),
            ),
          ),
          child: const Text('查看未完成原因'),
        ),
      );
    } else if (status == AgentStepStatus.cancelled) {
      content = const Text('本次操作已停止');
    } else {
      final result = output?['result'] as Map?;
      final action = operation;
      if (result == null) {
        content = const Text('任务记录未包含详情');
      } else if (action == 'create' || action == 'update') {
        content = _TaskSnapshot(task: result);
      } else if (action == 'list') {
        final tasks = result['tasks'] as List?;
        content = tasks == null
            ? const Text('任务记录未包含详情')
            : tasks.isEmpty
            ? const Text('查询时没有任务')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, task) in tasks.indexed) ...[
                    if (index > 0) ...[
                      const SizedBox(height: 20),
                      Divider(
                        height: 1,
                        color: colors.outlineVariant.withValues(alpha: .5),
                      ),
                      const SizedBox(height: 20),
                    ],
                    _TaskSnapshot(task: task as Map),
                  ],
                ],
              );
      } else if (result['updated'] == true) {
        content = Text(switch (action) {
          'pause' => '本次已暂停任务',
          'resume' => '本次已恢复任务',
          'delete' => '本次已删除任务',
          _ => '任务记录未包含详情',
        });
      } else {
        content = const Text('任务记录未包含详情');
      }
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: colors.onSurfaceVariant,
        ),
        child: content,
      ),
    );
  }
}

class _TaskSnapshot extends StatelessWidget {
  const _TaskSnapshot({required this.task});
  final Map task;

  @override
  Widget build(BuildContext context) {
    // Older tool records may not contain a full task snapshot.
    if (task['title'] is! String ||
        task['prompt'] is! String ||
        task['scheduleLabel'] is! String ||
        task['state'] is! String ||
        (task['state'] == 'scheduled' && task['runAt'] is! int)) {
      return const Text('任务记录未包含详情');
    }
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          task['scheduleLabel'] as String,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: GlobalUI.taskTimeColor(context),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          task['title'] as String,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        SelectableText(
          task['prompt'] as String,
          style: TextStyle(
            fontSize: 15,
            height: 1.6,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        Divider(height: 1, color: colors.outlineVariant.withValues(alpha: .5)),
        const SizedBox(height: 14),
        Text(
          task['state'] == 'scheduled'
              ? '记录时：待执行 · ${taskTime(task['runAt'] as int)}'
              : '记录时：${taskState(task['state'] as String)}',
          style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}
