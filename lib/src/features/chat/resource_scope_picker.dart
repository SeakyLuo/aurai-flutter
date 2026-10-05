import 'package:flutter/material.dart';
import '../../domain/resource_scope.dart';
import '../../widgets/empty_data_view.dart';
import 'floating_search_layout.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

String resourceScopeLabel(
  List<ResourceScope> scopes,
  List<Map<String, Object?>> groups,
  List<Map<String, Object?>> projects,
) {
  if (scopes.isEmpty) return '所有人可见';
  return scopes
      .map(
        (scope) =>
            (scope.type == 'group' ? groups : projects)
                    .where((target) => target['id'] == scope.id)
                    .firstOrNull?[scope.type == 'group' ? 'title' : 'name']
                as String? ??
            (scope.type == 'group' ? '已删除的群聊' : '已删除的项目'),
      )
      .join('、');
}

class ResourceScopeField extends StatelessWidget {
  const ResourceScopeField({
    super.key,
    required this.scopes,
    required this.groups,
    required this.projects,
    required this.onChanged,
    this.requiredGroup = false,
    this.visibility = true,
  });
  final List<ResourceScope> scopes;
  final List<Map<String, Object?>> groups;
  final List<Map<String, Object?>> projects;
  final ValueChanged<List<ResourceScope>>? onChanged;
  final bool requiredGroup;
  final bool visibility;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: Text(
            visibility ? '可见范围' : '使用范围',
            style: TextStyle(
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Material(
          color: settingsFieldColor(context),
          borderRadius: BorderRadius.circular(26),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(18, 8, 12, 8),
            title: Text(
              requiredGroup && scopes.isEmpty
                  ? '选择群聊或项目'
                  : scopes.isEmpty
                  ? (visibility ? '所有人可见' : '所有会话')
                  : (visibility
                        ? '部分可见'
                        : resourceScopeLabel(scopes, groups, projects)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: !visibility || scopes.isEmpty
                ? null
                : Text(
                    resourceScopeLabel(scopes, groups, projects),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
            trailing: onChanged == null
                ? null
                : const SettingsIcon(type: SettingsIconType.chevron),
            onTap: onChanged == null
                ? null
                : () async {
                    final result = await Navigator.push<List<ResourceScope>>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ResourceScopePicker(
                          groups: groups,
                          projects: projects,
                          selected: scopes,
                          requiredGroup: requiredGroup,
                          visibility: visibility,
                        ),
                      ),
                    );
                    if (result != null) onChanged!(result);
                  },
          ),
        ),
      ],
    ),
  );
}

class ResourceScopePicker extends StatefulWidget {
  const ResourceScopePicker({
    super.key,
    required this.groups,
    required this.projects,
    required this.selected,
    required this.requiredGroup,
    this.visibility = true,
  });
  final List<Map<String, Object?>> groups;
  final List<Map<String, Object?>> projects;
  final List<ResourceScope> selected;
  final bool requiredGroup;
  final bool visibility;
  @override
  State<ResourceScopePicker> createState() => _ResourceScopePickerState();
}

class _ResourceScopePickerState extends State<ResourceScopePicker> {
  late final _selected = widget.selected.toSet();
  late bool _partial = widget.requiredGroup || _selected.isNotEmpty;
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projects = widget.projects
        .where(
          (p) => (p['name'] as String).toLowerCase().contains(
            _search.text.toLowerCase(),
          ),
        )
        .toList();
    final groups = widget.groups
        .where(
          (g) => (g['title'] as String).toLowerCase().contains(
            _search.text.toLowerCase(),
          ),
        )
        .toList();
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        title: widget.requiredGroup
            ? '选择群聊或项目'
            : widget.visibility
            ? '可见范围'
            : '使用范围',
        onBack: () => Navigator.pop(context),
        actions: [
          SettingsGlassAction(
            label: '完成',
            icon: Icons.check_rounded,
            iconWidget: const SettingsIcon(type: SettingsIconType.check),
            onPressed: _partial && _selected.isEmpty
                ? null
                : () => Navigator.pop(
                    context,
                    _partial ? _selected.toList() : <ResourceScope>[],
                  ),
          ),
        ],
      ),
      body: SettingsPageBody(
        child: FloatingSearchLayout(
          itemCount: widget.groups.length + widget.projects.length,
          controller: _search,
          hintText: '搜索群聊或项目',
          enabled: _partial,
          bottom: 16,
          onChanged: (_) => setState(() {}),
          child: ListView(
            padding: settingsPagePadding(
              context,
              const EdgeInsets.fromLTRB(
                16,
                12,
                16,
                FloatingSearchLayout.clearance,
              ),
            ),
            children: [
              if (!widget.requiredGroup && _search.text.isEmpty)
                _tile(
                  widget.visibility ? '所有人可见' : '所有会话',
                  !_partial,
                  () => setState(() => _partial = false),
                ),
              if (!widget.requiredGroup && _search.text.isEmpty)
                _tile(
                  widget.visibility ? '部分可见' : '指定群聊或项目',
                  _partial,
                  () => setState(() => _partial = true),
                ),
              if (_partial) ...[
                if (projects.isNotEmpty) _heading('项目'),
                for (final project in projects)
                  _tile(
                    project['name'] as String,
                    _selected.contains(
                      ResourceScope.project(project['id'] as String),
                    ),
                    () => setState(() {
                      final scope = ResourceScope.project(
                        project['id'] as String,
                      );
                      if (!_selected.remove(scope)) _selected.add(scope);
                    }),
                  ),
                if (groups.isNotEmpty) _heading('群聊'),
                for (final group in groups)
                  _tile(
                    group['title'] as String,
                    _selected.contains(
                      ResourceScope.group(group['id'] as String),
                    ),
                    () => setState(() {
                      final scope = ResourceScope.group(group['id'] as String);
                      if (!_selected.remove(scope)) _selected.add(scope);
                    }),
                  ),
                if (groups.isEmpty && projects.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: EmptyDataView(title: '没有匹配的群聊或项目'),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(String title, bool selected, VoidCallback onTap) => ListTile(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    title: Text(title),
    onTap: onTap,
    trailing: selected
        ? const SettingsIcon(type: SettingsIconType.check)
        : null,
  );
  Widget _heading(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 14,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
