import 'library_detail_split.dart';
import 'package:flutter/material.dart';

import '../../domain/agent_models.dart';
import '../../domain/tool_models.dart';
import 'chat_controller.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'tool_action_icon.dart';
import 'tool_detail_page.dart';
import 'tool_approvals_page.dart';
import 'resource_scope_filter.dart';
import 'floating_search_layout.dart';
import '../../domain/resource_scope.dart';
import '../../widgets/empty_data_view.dart';
import '../../app/glass_notice.dart';
import '../../domain/tool_customization.dart';

class ToolsPage extends StatefulWidget {
  const ToolsPage({
    super.key,
    required this.controller,
    this.groupId,
    this.projectId,
  });
  final ChatController controller;
  final String? groupId, projectId;

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> {
  final _detailSplitKey = GlobalKey<LibraryDetailSplitState>();
  ChatController get controller => widget.controller;
  late ResourceScope? _scope = widget.groupId != null
      ? ResourceScope.group(widget.groupId!)
      : widget.projectId != null
      ? ResourceScope.project(widget.projectId!)
      : null;
  final _search = TextEditingController();
  List<Map<String, Object?>> _groups = [];
  List<Map<String, Object?>> _projects = [];
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final rows = await Future.wait([
        ToolCustomizations.groups(),
        ToolCustomizations.projects(),
      ]);
      if (mounted)
        setState(() {
          _groups = rows[0];
          _projects = rows[1];
        });
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showToast(
          SnackBar(content: Text(error.toString())),
          kind: ToastKind.error,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final resourceCount = controller.globalToolDefinitions
        .where(
          (tool) => matchesResourceFilter(
            ToolCustomizations.values[tool.name]?.scopes ?? [],
            widget.groupId != null
                ? ResourceScope.group(widget.groupId!)
                : widget.projectId != null
                ? ResourceScope.project(widget.projectId!)
                : null,
            _groups,
          ),
        )
        .length;
    final groups = <String, List<ToolDefinition>>{};
    for (final tool in controller.globalToolDefinitions) {
      if (!matchesResourceFilter(
            ToolCustomizations.values[tool.name]?.scopes ?? [],
            _scope,
            _groups,
          ) ||
          !(toolTitle(
                tool.name,
              ).toLowerCase().contains(_search.text.toLowerCase()) ||
              tool.description.toLowerCase().contains(
                _search.text.toLowerCase(),
              )))
        continue;
      final name = tool.name == 'runSkill'
          ? '技能'
          : switch (tool.capabilityId) {
              'web.read' || 'web.images' => '网页与搜索',
              'memory.manage' => '记忆',
              'skills' => '技能',
              'interactiveDecision' => '交互消息',
              'android.scheduled_tasks' => '定时任务',
              'android.network' => '网络',
              'android.notifications.observe' ||
              'android.notifications.send' => '通知',
              'android.documents' || 'local.attachments' => '文件与文档',
              'local.history' || 'local.ai_contacts' => '会话与朋友',
              'model.settings' || 'model.balance' || 'model.topUp' => '模型账户',
              _ => '设备与其他工具',
            };
      groups.putIfAbsent(name, () => []).add(tool);
    }
    return LibraryDetailSplit(
      key: _detailSplitKey,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: SettingsAppBar(
          title: '工具库',

          onBack: () => Navigator.pop(context),
        ),
        body: SettingsPageBody(
          child: FloatingSearchLayout(
            itemCount: resourceCount,
            controller: _search,
            onChanged: (_) => setState(() {}),
            hintText: '搜索工具',
            enabled: true,
            bottom: 16,
            trailingAction: resourceCount < 20
                ? null
                : ResourceScopeFilter(
                    groups: _groups,
                    projects: _projects,
                    value: _scope,
                    onChanged: (value) => setState(() => _scope = value),
                  ),
            child: groups.isEmpty
                ? const Center(child: EmptyDataView(title: '没有匹配的工具'))
                : ListView(
                    padding: EdgeInsets.fromLTRB(
                      18,
                      MediaQuery.paddingOf(context).top +
                          SettingsAppBar.toolbarHeight +
                          12,
                      18,
                      FloatingSearchLayout.clearance,
                    ),
                    children: [
                      Material(
                        color: settingsFieldColor(context),
                        borderRadius: BorderRadius.circular(26),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          contentPadding: const EdgeInsets.only(
                            left: 16,
                            right: 8,
                          ),
                          leading: SettingsIcon(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            type: SettingsIconType.permission,
                          ),
                          title: const Text('工具授权'),
                          trailing: SettingsIcon(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            type: SettingsIconType.chevron,
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  ToolApprovalsPage(controller: controller),
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
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
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
                                  contentPadding: const EdgeInsets.only(
                                    left: 16,
                                    right: 8,
                                  ),
                                  leading: ToolActionIcon(toolName: tool.name),
                                  title: Text(toolTitle(tool.name)),
                                  trailing: SettingsIcon(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    type: SettingsIconType.chevron,
                                  ),
                                  onTap: () async {
                                    await _detailSplitKey.currentState!.open(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ToolDetailPage(tool: tool),
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
          ),
        ),
      ),
    );
  }
}
