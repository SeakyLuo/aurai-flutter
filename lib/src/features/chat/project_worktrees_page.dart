import 'package:flutter/material.dart';
import '../../app/ui_action.dart';
import '../../app/glass_notice.dart';
import '../../platform/aurai_platform.dart';
import '../../storage/development_projects.dart';
import 'chat_controller.dart';
import 'app_confirmation_dialog.dart';
import 'app_dialog.dart';
import 'dialog_action_button.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'project_git_changes_page.dart';

class ProjectWorktreeSelection {
  const ProjectWorktreeSelection(this.id, this.name);
  final String? id;
  final String name;
}

class ProjectWorktreesPage extends StatefulWidget {
  const ProjectWorktreesPage({
    super.key,
    required this.project,
    required this.controller,
  });
  final DevelopmentProject project;
  final ChatController controller;
  @override
  State<ProjectWorktreesPage> createState() => _ProjectWorktreesPageState();
}

class _ProjectWorktreesPageState extends State<ProjectWorktreesPage> {
  Map<String, Object?>? _data;
  bool _busy = false;
  bool _loading = true;

  Future<Map<String, Object?>> _invoke(
    String operation, [
    Map<String, Object?> args = const {},
    String? workspace,
  ]) => AuraiPlatform.instance.deviceExtension('projectDevelopmentOperation', {
    'projectId': workspace ?? widget.project.id,
    'operation': operation,
    'arguments': args,
  });

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() =>
      runUiAction(context, () async {
        final data = await _invoke('listProjectWorktrees');
        if (mounted) setState(() => _data = data);
      }).then((_) {
        if (mounted) setState(() => _loading = false);
      });

  Future<void> _create() async {
    final branches = (_data!['branches'] as List).cast<String>();
    if (branches.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showGlassSnackBar(const SnackBar(content: Text('请先在项目中创建一次 Git 提交')));
      return;
    }
    final choice = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _CreateWorktreeDialog(
        branches: branches,
        current: _data!['branch'] as String,
      ),
    );
    if (choice == null || !mounted) return;
    setState(() => _busy = true);
    await runUiAction(context, () async {
      final created = await _invoke('createProjectWorktree', {
        'name': choice.$1,
        'baseBranch': choice.$2,
      });
      if (mounted)
        Navigator.pop(
          context,
          ProjectWorktreeSelection(
            created['id'] as String,
            created['name'] as String,
          ),
        );
    });
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _act(Map item, String action) async {
    final id = item['id'] as String;
    if (action == 'diff') {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => ProjectGitChangesPage.worktree(
            projectId: widget.project.id,
            worktreeId: id,
            worktreeName: item['name'] as String,
          ),
        ),
      );
      return;
    }
    final deleting = action == 'remove';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AppConfirmationDialog(
        title: deleting ? '删除这个工作树？' : '合并到主目录？',
        description: deleting
            ? '仅删除已合并且没有未提交修改的工作树。聊天记录保留，使用此目录的会话需要重新选择工作目录。'
            : '将已提交的修改合并到起始分支。主目录和工作树都需要没有未提交修改。',
        confirmLabel: deleting ? '删除' : '合并',
        confirmRole: deleting
            ? DialogActionRole.destructive
            : DialogActionRole.primary,
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    await runUiAction(context, () async {
      widget.controller.requireProjectIdle(widget.project.id);
      DevelopmentProjects.changingWorktrees.add(widget.project.id);
      try {
        await _invoke(
          deleting ? 'removeProjectWorktree' : 'mergeProjectWorktree',
          {'worktreeId': id},
        );
        if (deleting) {
          await widget.controller.projects.markWorktreeDeleted(id);
          await widget.controller.refreshConversations();
        }
      } finally {
        DevelopmentProjects.changingWorktrees.remove(widget.project.id);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showGlassSnackBar(
        SnackBar(content: Text(deleting ? '工作树已删除' : '已合并到主目录')),
      );
      await _load();
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final items = data == null ? const <Object?>[] : data['worktrees'] as List;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: SettingsAppBar(
          title: '工作树',
          onBack: _busy ? null : () => Navigator.pop(context),
          actions: [
            if (data?['available'] == true)
              SettingsGlassAction(
                label: '新建工作树',
                icon: Icons.add_rounded,
                iconWidget: const SettingsIcon(type: SettingsIconType.add),
                onPressed: _busy ? null : _create,
              ),
          ],
        ),
        body: data == null
            ? (_loading
                  ? const Center(child: CircularProgressIndicator())
                  : const SizedBox.shrink())
            : ListView(
                padding: settingsPagePadding(
                  context,
                  const EdgeInsets.fromLTRB(16, 8, 16, 24),
                ),
                children: [
                  ListTile(
                    title: const Text('主目录'),
                    subtitle: Text(
                      data['available'] == true
                          ? data['branch'] as String
                          : '当前项目还不是 Git 仓库',
                    ),
                    onTap: _busy
                        ? null
                        : () => Navigator.pop(
                            context,
                            const ProjectWorktreeSelection(null, '主目录'),
                          ),
                  ),
                  for (final item in items.cast<Map>())
                    Material(
                      color: settingsFieldColor(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Column(
                        children: [
                          ListTile(
                            title: Text(item['name'] as String),
                            subtitle: Text('基于 ${item['baseBranch']}'),
                            trailing: const SettingsIcon(
                              type: SettingsIconType.chevron,
                            ),
                            onTap: _busy
                                ? null
                                : () => Navigator.pop(
                                    context,
                                    ProjectWorktreeSelection(
                                      item['id'] as String,
                                      item['name'] as String,
                                    ),
                                  ),
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _act(item, 'diff'),
                                child: const Text('查看改动'),
                              ),
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _act(item, 'merge'),
                                child: const Text('合并'),
                              ),
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _act(item, 'remove'),
                                child: const Text('删除'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  if (items.isEmpty && data['available'] == true)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('还没有工作树', textAlign: TextAlign.center),
                    ),
                ],
              ),
      ),
    );
  }
}

class _CreateWorktreeDialog extends StatefulWidget {
  const _CreateWorktreeDialog({required this.branches, required this.current});
  final List<String> branches;
  final String current;
  @override
  State<_CreateWorktreeDialog> createState() => _CreateWorktreeDialogState();
}

class _CreateWorktreeDialogState extends State<_CreateWorktreeDialog> {
  final _name = TextEditingController();
  late String _branch = widget.branches.contains(widget.current)
      ? widget.current
      : widget.branches.first;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '新建工作树',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: 40,
            decoration: const InputDecoration(labelText: '名称'),
            onChanged: (_) => setState(() {}),
          ),
          DropdownButtonFormField<String>(
            initialValue: _branch,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '起始分支'),
            items: [
              for (final branch in widget.branches)
                DropdownMenuItem(value: branch, child: Text(branch)),
            ],
            onChanged: (value) => setState(() => _branch = value!),
          ),
          const SizedBox(height: 12),
          const Text('从分支最新提交创建，不包含未提交的修改。'),
          const SizedBox(height: 20),
          DialogActionButton(
            text: '创建',
            role: DialogActionRole.primary,
            onPressed: _name.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, (_name.text.trim(), _branch)),
          ),
        ],
      ),
    ),
  );
}
