import 'package:flutter/material.dart';

import '../../domain/agent_models.dart';
import '../../domain/tool_models.dart';
import 'chat_controller.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'tool_action_icon.dart';
import 'tool_detail_page.dart';
import 'tool_approvals_page.dart';

class ToolsPage extends StatefulWidget {
  const ToolsPage({super.key, required this.controller});
  final ChatController controller;

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> {
  ChatController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<ToolDefinition>>{};
    for (final tool in controller.globalToolDefinitions) {
      final name = tool.name == 'runSkill'
          ? '技能'
          : switch (tool.capabilityId) {
              'web.read' || 'web.images' => '网页与搜索',
              'memory.manage' => '记忆',
              'skills' => '技能',
              'android.scheduled_tasks' => '定时任务',
              'android.network' => '网络',
              'android.notifications.observe' ||
              'android.notifications.send' => '通知',
              'android.documents' || 'local.attachments' => '文件与文档',
              'local.history' || 'local.ai_contacts' => '会话与朋友',
              'model.balance' || 'model.topUp' => '模型账户',
              _ => '设备与其他工具',
            };
      groups.putIfAbsent(name, () => []).add(tool);
    }
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        title: '工具库',
        gradientBackground: true,
        onBack: () => Navigator.pop(context),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          18,
          MediaQuery.paddingOf(context).top + 76 + 12,
          18,
          MediaQuery.paddingOf(context).bottom + 32,
        ),
        children: [
          Material(
            color: settingsFieldColor(context),
            borderRadius: BorderRadius.circular(26),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.only(left: 16, right: 8),
              leading: const SettingsIcon(type: SettingsIconType.tools),
              title: const Text('工具授权'),
              trailing: const SettingsIcon(type: SettingsIconType.chevron),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ToolApprovalsPage(controller: controller),
                ),
              ),
            ),
          ),
          for (final group in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 24, 12, 10),
              child: Text(
                group.key,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Material(
              color: settingsFieldColor(context),
              borderRadius: BorderRadius.circular(26),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final tool in group.value)
                    ListTile(
                      contentPadding: const EdgeInsets.only(left: 16, right: 8),
                      leading: ToolActionIcon(toolName: tool.name),
                      title: Text(toolTitle(tool.name)),
                      trailing: const SettingsIcon(
                        type: SettingsIconType.chevron,
                      ),
                      onTap: () async {
                        await Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ToolDetailPage(tool: tool),
                          ),
                        );
                        if (mounted) setState(() {});
                      },
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
