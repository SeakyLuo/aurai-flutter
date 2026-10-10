import '../../app/glass_notice.dart';
import 'task_entry_card.dart';
import '../../app/ui_action.dart';
import 'task_conversation_navigation.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../domain/agent_models.dart';
import 'image_action_scope.dart';
import 'settings_icon.dart';
import 'sidebar_action_icon.dart';
import 'thinking_indicator.dart';
import 'subagent_detail_page.dart';

class SubagentToolActivity extends StatelessWidget {
  const SubagentToolActivity({
    super.key,
    required this.status,
    this.requestJson,
    this.resultJson,
    this.organizedTask = false,
  });
  final AgentStepStatus status;
  final bool organizedTask;
  final String? requestJson, resultJson;

  @override
  Widget build(BuildContext context) {
    final request = requestJson == null
        ? const <String, dynamic>{}
        : jsonDecode(requestJson!) as Map;
    final result = resultJson == null
        ? const <String, dynamic>{}
        : jsonDecode(resultJson!) as Map;
    final title = organizedTask
        ? (result['title'] ?? request['title']) as String? ?? '任务'
        : request['title'] as String? ?? '子代理';
    final runId = result['runId'] as String?;
    final taskId = result['taskId'] as String?;
    final targetId = organizedTask ? taskId : runId;
    final error = result['error'] as String?;
    final label = switch (status) {
      AgentStepStatus.running => '执行中',
      AgentStepStatus.completed => '已完成',
      AgentStepStatus.cancelled => '已停止',
      AgentStepStatus.failed => '未完成',
    };
    if (organizedTask) {
      return TaskEntryCard(
        title: title,
        description: request['description'] as String? ?? '点击查看任务',
        status:
            status == AgentStepStatus.completed &&
                request['startExecution'] == false
            ? '已创建'
            : label,
        failed: status == AgentStepStatus.failed,
        onTap: targetId != null
            ? () async {
                final controller = ImageActionScope.of(context);
                await runUiAction(
                  context,
                  () => openTaskConversation(
                    context,
                    controller,
                    taskId!,
                    title: title,
                  ),
                );
              }
            : error != null
            ? () async {
                ScaffoldMessenger.of(context).showToast(
                  SnackBar(content: Text(error)),
                  kind: ToastKind.error,
                );
              }
            : null,
      );
    }
    return Semantics(
      button: targetId != null || error != null,
      label: '$title，$label',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: targetId == null
            ? error == null
                  ? null
                  : () => ScaffoldMessenger.of(context).showToast(
                      SnackBar(content: Text(error)),
                      kind: ToastKind.error,
                    )
            : () {
                final controller = ImageActionScope.of(context);
                Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SubagentDetailPage(
                      controller: controller,
                      runId: runId!,
                    ),
                  ),
                );
              },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: [
              Expanded(
                child: ThinkingIndicator(
                  leading: SizedBox.square(
                    dimension: 18,
                    child: FittedBox(
                      child: organizedTask
                          ? const SettingsIcon(type: SettingsIconType.job)
                          : SidebarActionIcon(
                              type: SidebarActionIconType.group,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                    ),
                  ),
                  label: '$title · $label',
                  animate: status == AgentStepStatus.running,
                  singleLine: true,
                ),
              ),
              if (targetId != null)
                const SizedBox(
                  width: 20,
                  child: SettingsIcon(type: SettingsIconType.chevron),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
