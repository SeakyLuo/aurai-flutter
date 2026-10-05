import '../../app/glass_notice.dart';
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
  });
  final AgentStepStatus status;
  final String? requestJson, resultJson;

  @override
  Widget build(BuildContext context) {
    final request = requestJson == null
        ? const <String, dynamic>{}
        : jsonDecode(requestJson!) as Map;
    final result = resultJson == null
        ? const <String, dynamic>{}
        : jsonDecode(resultJson!) as Map;
    final title = request['title'] as String? ?? '子代理';
    final runId = result['runId'] as String?;
    final error = result['error'] as String?;
    final label = switch (status) {
      AgentStepStatus.running => '执行中',
      AgentStepStatus.completed => '已完成',
      AgentStepStatus.cancelled => '已停止',
      AgentStepStatus.failed => '未完成',
    };
    return Semantics(
      button: runId != null || error != null,
      label: '$title，$label',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: runId == null
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
                      runId: runId,
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
                      child: SidebarActionIcon(
                        type: SidebarActionIconType.group,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  label: '$title · $label',
                  animate: status == AgentStepStatus.running,
                  singleLine: true,
                ),
              ),
              if (runId != null)
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
