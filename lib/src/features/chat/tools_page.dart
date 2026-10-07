import 'library_detail_split.dart';
import 'package:flutter/material.dart';

import '../../domain/agent_models.dart';
import '../../domain/tool_models.dart';
import 'chat_controller.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'tool_action_icon.dart';
import 'tool_detail_page.dart';
import 'tool_library_group.dart';
import 'tool_approvals_page.dart';
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
    this.senderId,
  });
  final ChatController controller;
  final String? groupId, projectId;
  final String? senderId;

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> {
  final _detailSplitKey = GlobalKey<LibraryDetailSplitState>();
  ChatController get controller => widget.controller;
  late final ResourceScope? _scope = widget.groupId != null
      ? ResourceScope.group(widget.groupId!)
      : widget.projectId != null
      ? ResourceScope.project(widget.projectId!)
      : null;
  final _search = TextEditingController();
  bool _matches(List<ResourceScope> scopes, ResourceScope? filter) =>
      widget.senderId != null
      ? matchesResourceScope(scopes, null, projectId: widget.projectId)
      : matchesResourceFilter(scopes, filter, _groups);
  List<Map<String, Object?>> _groups = [];
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
      final rows = await ToolCustomizations.groups();
      if (mounted)
        setState(() {
          _groups = rows;
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
    final tools = controller.globalToolDefinitions;
    final resourceCount = tools
        .where(
          (tool) => _matches(
            ToolCustomizations.values[tool.name]?.scopes ?? [],
            widget.groupId != null
                ? ResourceScope.group(widget.groupId!)
                : widget.projectId != null
                ? ResourceScope.project(widget.projectId!)
                : null,
          ),
        )
        .length;
    final groups = <ToolLibraryGroup, List<ToolDefinition>>{};
    for (final tool in tools) {
      if (!_matches(
            ToolCustomizations.values[tool.name]?.scopes ?? [],
            _scope,
          ) ||
          !(toolTitle(
                tool.name,
              ).toLowerCase().contains(_search.text.toLowerCase()) ||
              tool.summary.toLowerCase().contains(_search.text.toLowerCase()) ||
              tool.description.toLowerCase().contains(
                _search.text.toLowerCase(),
              )))
        continue;
      final group = ToolLibraryGroup.forTool(tool);
      groups.putIfAbsent(group, () => []).add(tool);
    }
    final orderedGroups = groups.entries.toList()
      ..sort((a, b) => a.key.index.compareTo(b.key.index));
    return LibraryDetailSplit(
      key: _detailSplitKey,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: SettingsAppBar(
          title: widget.senderId == null ? '工具库' : '工具',

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
                              builder: (_) => ToolApprovalsPage(
                                controller: controller,
                                senderId: widget.senderId,
                              ),
                            ),
                          ),
                        ),
                      ),
                      for (final group in orderedGroups) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 24, 12, 10),
                          child: Text(
                            group.key.label,
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
