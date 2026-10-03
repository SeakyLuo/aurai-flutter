import 'package:flutter/material.dart';
import '../../app/ui_action.dart';
import 'choice_sheet.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class ProjectWorktreeCreatePage extends StatefulWidget {
  const ProjectWorktreeCreatePage({
    super.key,
    required this.branches,
    required this.current,
    required this.onCreate,
  });
  final List<String> branches;
  final String current;
  final Future<void> Function(String name, String branch) onCreate;
  @override
  State<ProjectWorktreeCreatePage> createState() =>
      _ProjectWorktreeCreatePageState();
}

class _ProjectWorktreeCreatePageState extends State<ProjectWorktreeCreatePage> {
  final _name = TextEditingController();
  late String _branch = widget.branches.contains(widget.current)
      ? widget.current
      : widget.branches.first;
  bool _busy = false;
  bool get _canSave => !_busy && _name.text.trim().isNotEmpty;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _chooseBranch() async {
    FocusScope.of(context).unfocus();
    final branch = await showChoiceSheet<String>(
      context,
      title: '起始分支',
      selected: _branch,
      choices: [
        for (final branch in widget.branches) (value: branch, label: branch),
      ],
    );
    if (branch != null && mounted) setState(() => _branch = branch);
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final saved = await runUiAction(
      context,
      () => widget.onCreate(_name.text.trim(), _branch),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        title: '新建工作树',
        onBack: _busy ? null : () => Navigator.pop(context),
        actions: [
          SettingsGlassAction(
            label: _busy ? '正在创建' : '创建',
            icon: Icons.check_rounded,
            iconWidget: SettingsIcon(
              type: SettingsIconType.check,
              color: SettingsGlassAction.foregroundColor(
                context,
                enabled: _canSave,
              ),
            ),
            onPressed: _canSave ? _save : null,
          ),
        ],
      ),
      body: SettingsPageBody(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: settingsPagePadding(
                context,
                const EdgeInsets.fromLTRB(16, 12, 16, 32),
              ),
              children: [
                TextField(
                  controller: _name,
                  autofocus: true,
                  enabled: !_busy,
                  maxLength: 40,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) {
                    if (_canSave) _save();
                  },
                  decoration: InputDecoration(
                    hintText: '工作树名称',
                    counterText: '',
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
                const SizedBox(height: 24),
                Material(
                  color: settingsFieldColor(context),
                  borderRadius: BorderRadius.circular(26),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsetsDirectional.only(
                      start: 16,
                      end: 12,
                    ),
                    leading: const SettingsIcon(type: SettingsIconType.git),
                    title: const Text('起始分支', style: TextStyle(fontSize: 15)),
                    subtitle: Text(
                      _branch,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const SettingsIcon(
                      type: SettingsIconType.chevron,
                    ),
                    onTap: _busy ? null : _chooseBranch,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '从分支最新提交创建，不包含未提交的修改。',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
