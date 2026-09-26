import '../app/glass_notice.dart';
import '../domain/error_message.dart';
import 'skill_visibility_picker.dart';
import 'package:flutter/foundation.dart';
import 'skill_dependency_picker.dart';
import 'skill_icon.dart';
import 'skill_icon_picker.dart';
import 'package:flutter/material.dart';
import '../features/chat/settings_appearance.dart';
import '../features/chat/glass_surface.dart';
import '../features/chat/settings_icon.dart';
import '../scheduling/task_unsaved_dialog.dart';
import 'skill_store.dart';
import 'skill_statistics_view.dart';

class SkillEditor extends StatefulWidget {
  const SkillEditor({super.key, required this.store, required this.skill});
  final SkillStore store;
  final SavedSkill skill;
  @override
  State<SkillEditor> createState() => _SkillEditorState();
}

class _SkillEditorState extends State<SkillEditor> {
  late SavedSkill _saved = widget.skill;
  late String _visibility = _saved.visibility;
  late Set<String> _visibleTo = _saved.visibleTo.toSet();
  late final _name = TextEditingController(text: _saved.name);
  late final _description = TextEditingController(text: _saved.description);
  late final _instructions = TextEditingController(text: _saved.instructions);
  late final _script = TextEditingController(text: _saved.script);
  late String _icon = _saved.icon;
  late bool _enabled = _saved.enabled;
  late Set<String> _dependencies = _saved.dependencyIds.toSet();
  bool _busy = false, _leaving = false;
  bool get _dirty =>
      _saved.id.isEmpty ||
      _visibility != _saved.visibility ||
      !setEquals(_visibleTo, _saved.visibleTo.toSet()) ||
      _name.text != _saved.name ||
      _description.text != _saved.description ||
      _instructions.text != _saved.instructions ||
      _script.text != _saved.script ||
      _enabled != _saved.enabled ||
      _icon != _saved.icon ||
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
  ).showGlassSnackBar(SnackBar(content: Text(message)));
  Future<bool> _save() async {
    setState(() => _busy = true);
    try {
      await widget.store.save(
        SavedSkill(
          id: _saved.id,
          visibility: _visibility,
          visibleTo: _visibleTo.toList(),
          dependencyIds: _dependencies.toList(),
          name: _name.text,
          description: _description.text,
          instructions: _instructions.text,
          script: _script.text,
          enabled: _enabled,
          revision: _saved.revision,
          icon: _icon,
        ),
        previousName: _saved.id.isEmpty ? null : _saved.id,
      );
      if (!mounted) return true;
      setState(() {
        _saved = widget.store.library.singleWhere(
          (s) =>
              s.name == _name.text.trim() &&
              s.ownerId ==
                  (widget.skill.ownerId.isEmpty
                      ? widget.store.ownerId
                      : widget.skill.ownerId),
        );
        _visibleTo = _saved.visibleTo.toSet();
        _enabled = _saved.enabled;
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
    final items = widget.store.library
        .where((s) => _dependencies.contains(s.id))
        .toList();
    if (_dependencies.isEmpty) return '无';
    if (items.length != _dependencies.length) return '部分依赖已删除，请重新选择';
    return '${items.take(2).map((s) => "${s.name}${!widget.store.usesInstallations
        ? ''
        : !widget.store.isInstalled(s.id)
        ? '（未安装）'
        : s.enabled
        ? ''
        : '（已停用）'}").join('、')}${items.length > 2 ? ' +${items.length - 2}' : ''}';
  }

  Widget _field(
    String label,
    TextEditingController controller,
    int limit, {
    bool multiline = false,
    Widget? prefixIcon,
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
            prefixIcon: prefixIcon,
            prefixIconConstraints: const BoxConstraints(
              minWidth: 60,
              minHeight: 48,
            ),
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
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        title: _saved.id.isEmpty ? '新建技能' : '编辑技能',
        onBack: _close,
        actions: [
          SettingsGlassActionSurface(
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
              ],
            ),
          ),
        ],
      ),
      body: SettingsPageBody(
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: settingsPagePadding(
                  context,
                  const EdgeInsets.fromLTRB(16, 16, 16, 32),
                ),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  _field(
                    '名称',
                    _name,
                    60,
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 6, right: 4),
                      child: Tooltip(
                        message: '选择技能图标',
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: _busy
                                ? null
                                : () async {
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                    final icon = await showSkillIconPicker(
                                      context,
                                      _icon,
                                    );
                                    if (mounted && icon != null)
                                      setState(() => _icon = icon);
                                  },
                            child: SizedBox.square(
                              dimension: 48,
                              child: Center(child: SkillIcon(_icon)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  _field('简介', _description, 300, multiline: true),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                    child: Text(
                      '可见范围',
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
                        leading: SettingsIcon(
                          type: _visibility == 'private'
                              ? SettingsIconType.eyeOff
                              : SettingsIconType.eye,
                        ),
                        title: Text(
                          skillVisibilityLabel(_visibility),
                          style: const TextStyle(fontSize: 16),
                        ),
                        trailing: const SettingsIcon(
                          type: SettingsIconType.chevron,
                        ),
                        onTap:
                            _busy ||
                                (_saved.id.isNotEmpty &&
                                    !widget.store.canManageVisibility(_saved))
                            ? null
                            : () async {
                                final value =
                                    await Navigator.push<(String, Set<String>)>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SkillVisibilityPicker(
                                          store: widget.store,
                                          visibility: _visibility,
                                          selected: _visibleTo,
                                        ),
                                      ),
                                    );
                                if (mounted && value != null)
                                  setState(() {
                                    _visibility = value.$1;
                                    _visibleTo = value.$2;
                                  });
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
    ),
  );
}
