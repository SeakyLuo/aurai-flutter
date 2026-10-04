import 'package:flutter/material.dart';
import '../../app/global_ui.dart';
import '../../domain/resource_scope.dart';
import '../../scheduling/task_filter_menu.dart';
import 'resource_scope_picker.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class ResourceScopeFilter extends StatelessWidget {
  const ResourceScopeFilter({
    super.key,
    required this.groups,
    required this.projects,
    required this.value,
    required this.onChanged,
    this.status,
    this.onStatus,
  });
  final List<Map<String, Object?>> groups, projects;
  final ResourceScope? value;
  final ValueChanged<ResourceScope?> onChanged;
  final String? status;
  final ValueChanged<String>? onStatus;

  Future<void> _open(BuildContext context) async {
    final box = context.findRenderObject()! as RenderBox;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    if (onStatus != null) {
      final kind = await showTaskChoiceMenu(
        context,
        anchor: anchor,
        selected: '',
        label: '筛选',
        choices: [
          (value: 'status', label: status == 'disabled' ? '状态：已停用' : '状态：已启用'),
          (
            value: 'scope',
            label: value == null
                ? '范围：全部'
                : resourceScopeLabel([value!], groups, projects),
          ),
        ],
      );
      if (!context.mounted || kind == null) return;
      if (kind == 'status') {
        final selected = await showTaskChoiceMenu(
          context,
          anchor: anchor,
          selected: status!,
          label: '技能状态',
          choices: const [
            (value: 'enabled', label: '已启用'),
            (value: 'disabled', label: '已停用'),
          ],
        );
        if (context.mounted && selected != null) onStatus!(selected);
        return;
      }
    }
    final targets = <String, ResourceScope>{
      for (final p in projects)
        'project:${p['id']}': ResourceScope.project(p['id'] as String),
      for (final g in groups)
        'group:${g['id']}': ResourceScope.group(g['id'] as String),
    };
    final selected = await showTaskChoiceMenu(
      context,
      anchor: anchor,
      selected: value == null ? '' : '${value!.type}:${value!.id}',
      label: '使用范围',
      choices: [
        (value: '', label: '全部范围'),
        for (final p in projects)
          (value: 'project:${p['id']}', label: '项目 · ${p['name']}'),
        for (final g in groups)
          (value: 'group:${g['id']}', label: '群聊 · ${g['title']}'),
      ],
    );
    if (context.mounted && selected != null) onChanged(targets[selected]);
  }

  @override
  Widget build(BuildContext context) => Builder(
    builder: (anchor) => SettingsGlassAction(
      label: '筛选',
      icon: Icons.filter_list_rounded,
      onPressed: () => _open(anchor),
      iconWidget: SettingsIcon(
        type: SettingsIconType.filter,
        color: value != null || status == 'disabled'
            ? GlobalUI.highlightTextColor(context)
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
