import 'package:flutter/material.dart';
import '../features/chat/delete_confirmation_dialog.dart';
import '../features/chat/settings_appearance.dart';
import '../features/chat/settings_icon.dart';
import '../scheduling/task_unsaved_dialog.dart';
import 'skill_store.dart';

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
  late bool _enabled = _saved.enabled;
  bool _busy = false, _leaving = false;
  bool get _dirty =>
      _name.text != _saved.name ||
      _description.text != _saved.description ||
      _instructions.text != _saved.instructions ||
      _script.text != _saved.script ||
      _enabled != _saved.enabled;
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
          name: _name.text,
          description: _description.text,
          instructions: _instructions.text,
          script: _script.text,
          enabled: _enabled,
          revision: _saved.revision,
        ),
        previousName: _saved.name,
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
      if (mounted) _notice(e is StateError ? e.message : '保存失败，请重试');
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
    } on Object {
      if (mounted) _notice('删除失败，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    String label,
    TextEditingController controller,
    int limit, {
    bool multiline = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .4,
      ),
      child: TextField(
        controller: controller,
        enabled: !_busy,
        minLines: 1,
        maxLines: multiline ? null : 1,
        maxLength: limit,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          counterText: '',
          filled: true,
          fillColor: settingsFieldColor(context),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
        ),
      ),
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
          SettingsGlassAction(
            label: '保存技能',
            icon: Icons.check_rounded,
            iconWidget: Opacity(
              opacity: _dirty && !_busy ? 1 : .3,
              child: const SettingsIcon(type: SettingsIconType.check),
            ),
            onPressed: _dirty && !_busy ? () => _save() : null,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _field('名称', _name, 60),
                _field('简介', _description, 300, multiline: true),
                _field('使用说明', _instructions, 12000, multiline: true),
                SwitchListTile.adaptive(
                  title: const Text('启用技能'),
                  value: _enabled,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _enabled = value),
                ),
                ExpansionTile(
                  title: const Text('实现详情'),
                  children: [
                    _field('执行脚本（可选）', _script, 15000, multiline: true),
                  ],
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: _busy ? null : _delete,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Text('删除技能'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
