import '../domain/error_message.dart';
import 'package:flutter/foundation.dart';
import 'skill_dependency_picker.dart';
import 'skill_icon.dart';
import 'skill_icon_picker.dart';
import 'package:flutter/material.dart';
import '../features/chat/delete_confirmation_dialog.dart';
import '../features/chat/settings_appearance.dart';
import '../features/chat/glass_surface.dart';
import '../features/chat/settings_icon.dart';
import '../scheduling/task_unsaved_dialog.dart';
import 'skill_store.dart';
import 'skill_statistics_view.dart';
import 'skill_permission.dart';
import 'skill_permission_picker.dart';
import 'skill_action_menu.dart';
import '../scheduling/task_action_menu.dart';

class SkillEditor extends StatefulWidget {
  const SkillEditor({super.key, required this.store, required this.skill});
  final SkillStore store;
  final SavedSkill skill;
  @override
  State<SkillEditor> createState() => _SkillEditorState();
}

class _SkillEditorState extends State<SkillEditor> {
  late SavedSkill _saved = widget.skill;
  late final _name = TextEditingController(text: _saved.name);
  late final _description = TextEditingController(text: _saved.description);
  late final _instructions = TextEditingController(text: _saved.instructions);
  late final _script = TextEditingController(text: _saved.script);
  late String _icon = _saved.icon;
  late bool _enabled = _saved.enabled;
  late SkillPermission? _permission = widget.store.permissionOverrideFor(
    _saved.id,
  );
  late Set<String> _dependencies = _saved.dependencyIds.toSet();
  bool _busy = false, _leaving = false;
  bool get _dirty =>
      _name.text != _saved.name ||
      _description.text != _saved.description ||
      _instructions.text != _saved.instructions ||
      _script.text != _saved.script ||
      _enabled != _saved.enabled ||
      _icon != _saved.icon ||
      _permission != widget.store.permissionOverrideFor(_saved.id) ||
      !setEquals(_dependencies, _saved.dependencyIds.toSet());
  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _instructions.dispose();
    _script.dispose();
    super.dispose();
  }

  void _notice(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
  Future<bool> _save() async {
    setState(() => _busy = true);
    try {
      await widget.store.save(
        SavedSkill(
          dependencyIds: _dependencies.toList(),
          name: _name.text,
          description: _description.text,
          instructions: _instructions.text,
          script: _script.text,
          enabled: _enabled,
          revision: _saved.revision,
          icon: _icon,
        ),
        previousName: _saved.name,
        permission: _permission,
        updatePermission: true,
      );
      if (!mounted) return true;
      setState(() {
        _saved = widget.store.read(_name.text.trim());
        _name.text = _saved.name;
        _description.text = _saved.description;
        _instructions.text = _saved.instructions;
      });
      _notice('技能已保存');
      return true;
    } on Object catch (e) {
      if (mounted)
        _notice(e is StateError ? e.message : '保存失败，请重试：${errorMessage(e)}');
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _leave() {
    setState(() => _leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _close() async {
    if (_busy) return;
    if (_dirty) {
      final choice = await showDialog<String>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: .24),
        builder: (_) => const TaskUnsavedDialog(description: '技能还有未保存的修改。'),
      );
      if (!mounted || choice == null) return;
      if (choice == 'save' && !await _save()) return;
    }
    if (mounted) _leave();
  }

  Future<void> _menu(BuildContext buttonContext) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final box = buttonContext.findRenderObject()! as RenderBox;
    final action = await showSkillActionMenu(
      context,
      box.localToGlobal(Offset(0, box.size.height)),
      _saved.enabled,
    );
    if (!mounted || action == null) return;
    if (action == 'delete') {
      await _delete();
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.store.save(
        SavedSkill(
          dependencyIds: _saved.dependencyIds,
          name: _saved.name,
          description: _saved.description,
          instructions: _saved.instructions,
          script: _saved.script,
          enabled: !_saved.enabled,
          revision: _saved.revision,
          icon: _saved.icon,
        ),
        previousName: _saved.name,
      );
      if (!mounted) return;
      setState(() {
        _saved = widget.store.read(_saved.name);
        _enabled = _saved.enabled;
      });
      _notice(_enabled ? '技能已启用' : '技能已停用');
    } on Object catch (e) {
      if (mounted)
        _notice(e is StateError ? e.message : '操作失败，请重试：${errorMessage(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final yes = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .24),
      builder: (_) => const DeleteConfirmationDialog(
        title: '删除技能？',
        description: '删除后，Aurai 将无法再查找和调用这个技能。',
      ),
    );
    if (!mounted || yes != true) return;
    setState(() => _busy = true);
    try {
      await widget.store.delete(_saved.name);
      if (mounted) {
        _notice('技能已删除');
        _leave();
      }
    } on Object catch (error) {
      if (mounted)
        _notice(
          error is StateError
              ? error.message
              : '删除失败，请重试：${errorMessage(error)}',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseDependencies() async {
    final selected = await Navigator.push<Set<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => SkillDependencyPicker(
          store: widget.store,
          skillId: _saved.id,
          selected: _dependencies,
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _dependencies = selected);
  }

  String _dependencyLabel() {
    final items = widget.store.skills
        .where((s) => _dependencies.contains(s.id))
        .toList();
    if (_dependencies.isEmpty) return '无';
    if (items.length != _dependencies.length) return '部分依赖已删除，请重新选择';
    return '${items.take(2).map((s) => "${s.name}${s.enabled ? '' : '（已停用）'}").join('、')}${items.length > 2 ? ' +${items.length - 2}' : ''}';
  }

  Widget _field(
    String label,
    TextEditingController controller,
    int limit, {
    bool multiline = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        TextField(
          controller: controller,
          enabled: !_busy,
          minLines: multiline ? 3 : 1,
          maxLines: multiline ? 8 : 1,
          maxLength: limit,
          keyboardType: multiline
              ? TextInputType.multiline
              : TextInputType.text,
          textInputAction: multiline
              ? TextInputAction.newline
              : TextInputAction.next,
          onChanged: (_) => setState(() {}),
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            filled: true,
            fillColor: settingsFieldColor(context),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 20,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(26),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _leaving,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _close();
    },
    child: Scaffold(
      appBar: SettingsAppBar(
        title: '技能详情',
        onBack: _close,
        actions: [
          GlassSurface(
            radius: 28,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RoundAction(
                  label: _busy ? '正在保存' : '保存技能',
                  icon: Icons.check_rounded,
                  iconWidget: Opacity(
                    opacity: _dirty && !_busy ? 1 : .3,
                    child: const SettingsIcon(type: SettingsIconType.check),
                  ),
                  onPressed: _dirty && !_busy ? () => _save() : null,
                ),
                Builder(
                  builder: (buttonContext) => RoundAction(
                    label: '更多',
                    icon: Icons.more_vert,
                    iconWidget: const TaskActionIcon('more'),
                    onPressed: _busy ? null : () => _menu(buttonContext),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                  child: Text(
                    '图标',
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Material(
                    color: settingsFieldColor(context),
                    borderRadius: BorderRadius.circular(26),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      leading: ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          Theme.of(context).colorScheme.onSurface,
                          BlendMode.srcIn,
                        ),
                        child: SkillIcon(_icon),
                      ),
                      title: Text(
                        skillIcons[_icon]!,
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: const SettingsIcon(
                        type: SettingsIconType.chevron,
                      ),
                      onTap: _busy
                          ? null
                          : () async {
                              FocusManager.instance.primaryFocus?.unfocus();
                              final icon = await showSkillIconPicker(
                                context,
                                _icon,
                              );
                              if (mounted && icon != null)
                                setState(() => _icon = icon);
                            },
                    ),
                  ),
                ),
                _field('名称', _name, 60),
                _field('简介', _description, 300, multiline: true),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                  child: Text(
                    '权限',
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Material(
                    color: settingsFieldColor(context),
                    borderRadius: BorderRadius.circular(26),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      title: Text(
                        _permission?.label ??
                            '默认 · ${widget.store.defaultPermission.label}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: const SettingsIcon(
                        type: SettingsIconType.chevron,
                      ),
                      onTap: _busy
                          ? null
                          : () async {
                              FocusManager.instance.primaryFocus?.unfocus();
                              final permission =
                                  await showSkillPermissionPicker(
                                    context,
                                    _permission ??
                                        widget.store.defaultPermission,
                                  );
                              if (permission != null && mounted)
                                setState(
                                  () => _permission = permission.permission,
                                );
                            },
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                  child: Text(
                    '依赖技能',
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Material(
                    color: settingsFieldColor(context),
                    borderRadius: BorderRadius.circular(26),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      title: ListenableBuilder(
                        listenable: widget.store,
                        builder: (_, _) => Text(
                          _dependencyLabel(),
                          style: const TextStyle(fontSize: 16),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      trailing: const SettingsIcon(
                        type: SettingsIconType.chevron,
                      ),
                      onTap: _busy ? null : _chooseDependencies,
                    ),
                  ),
                ),
                _field('使用说明', _instructions, 10000, multiline: true),
                _field('执行脚本（可选）', _script, 50000, multiline: true),
                SkillStatisticsView(store: widget.store, skillId: _saved.id),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
