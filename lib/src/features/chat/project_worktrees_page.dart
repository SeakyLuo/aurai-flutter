import 'package:flutter/material.dart';
import '../../app/ui_action.dart';
import '../../app/glass_notice.dart';
import '../../platform/aurai_platform.dart';
import '../../storage/development_projects.dart';
import '../../storage/project_directory.dart';
import '../../storage/project_directories.dart';
import 'chat_controller.dart';
import 'app_confirmation_dialog.dart';
import 'project_worktree_create_page.dart';
import 'dialog_action_button.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'header_action_menu.dart';
import 'conversation_menu_icon.dart';
import 'project_git_changes_page.dart';

class ProjectWorktreesPage extends StatefulWidget {
  const ProjectWorktreesPage({
    super.key,
    required this.project,
    required this.controller,
    required this.directory,
  });
  final DevelopmentProject project;
  final ProjectDirectory directory;
  final ChatController controller;
  @override
  State<ProjectWorktreesPage> createState() => _ProjectWorktreesPageState();
}

class _ProjectWorktreesPageState extends State<ProjectWorktreesPage> {
  Map<String, Object?>? _data;
  bool _busy = false;
  bool _loading = true;
  Set<String> _associated = {};

  Future<Map<String, Object?>> _invoke(
    String operation, [
    Map<String, Object?> args = const {},
    String? workspace,
  ]) => AuraiPlatform.instance.deviceExtension('projectDevelopmentOperation', {
    'projectId': workspace ?? widget.directory.workspaceId,
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
        if (data['available'] != true) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showGlassSnackBar(const SnackBar(content: Text('此目录不是 Git 仓库')));
            Navigator.pop(context);
          }
          return;
        }
        final directories = await ProjectDirectories(
          widget.controller.groupStore.database,
        ).list(widget.project);
        if (mounted)
          setState(() {
            _data = data;
            _associated = directories.map((item) => item.uri).toSet();
          });
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
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectWorktreeCreatePage(
          branches: branches,
          current: _data!['branch'] as String,
          onCreate: (name, branch) async {
            widget.controller.requireProjectIdle(widget.project.id);
            final result = await _invoke('createProjectWorktree', {
              'name': name,
              'baseBranch': branch,
            });
            await ProjectDirectories(widget.controller.groupStore.database).add(
              widget.project,
              ProjectDirectory(
                uri: 'aurai://project/${result['id']}',
                name: result['name'] as String,
                repositoryUri: widget.directory.uri,
              ),
            );
          },
        ),
      ),
    );
    if (created != true || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showGlassSnackBar(const SnackBar(content: Text('工作树已创建并关联到项目')));
    await _load();
  }

  Future<void> _act(Map item, String action) async {
    final id = item['id'] as String;
    if (action == 'attach') {
      await runUiAction(context, () async {
        widget.controller.requireProjectIdle(widget.project.id);
        await ProjectDirectories(widget.controller.groupStore.database).add(
          widget.project,
          ProjectDirectory(
            uri: 'aurai://project/$id',
            name: item['name'] as String,
            repositoryUri: widget.directory.uri,
          ),
        );
        await _load();
      });
      return;
    }
    if (action == 'diff') {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => ProjectGitChangesPage.worktree(
            projectId: widget.directory.workspaceId,
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
            ? '仅删除已合并且没有未提交修改的工作树，并从关联项目中移除。聊天记录保留。'
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
      final affected = await ProjectDirectories(
        widget.controller.groupStore.database,
      ).projectsUsingRepository(widget.directory.uri);
      affected.add(widget.project.id);
      for (final projectId in affected) {
        widget.controller.requireProjectIdle(projectId);
      }
      DevelopmentProjects.changingWorktrees.addAll(affected);
      try {
        await _invoke(
          deleting ? 'removeProjectWorktree' : 'mergeProjectWorktree',
          {'worktreeId': id},
        );
        if (deleting) {
          await ProjectDirectories(
            widget.controller.groupStore.database,
          ).removeWorktree('aurai://project/$id');
          await widget.controller.refreshConversations();
        }
      } finally {
        DevelopmentProjects.changingWorktrees.removeAll(affected);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showGlassSnackBar(
        SnackBar(content: Text(deleting ? '工作树已删除' : '已合并到主目录')),
      );
      await _load();
    });
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _menu(BuildContext anchor, Map item) async {
    final action = await showHeaderActionMenu(
      anchor,
      destructiveValues: const {'remove'},
      items: [
        if (!_associated.contains('aurai://project/${item['id']}'))
          (
            value: 'attach',
            label: '关联到项目',
            icon: const SettingsIcon(type: SettingsIconType.add),
          ),
        (
          value: 'merge',
          label: '合并到主目录',
          icon: const SettingsIcon(type: SettingsIconType.git),
        ),
        (
          value: 'remove',
          label: '删除工作树',
          icon: const ConversationMenuIcon(
            type: ConversationMenuIconType.delete,
          ),
        ),
      ],
    );
    if (action != null && mounted) await _act(item, action);
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final items = data == null ? const <Object?>[] : data['worktrees'] as List;
    final canCreate =
        data?['available'] == true && (data!['branches'] as List).isNotEmpty;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: SettingsAppBar(
          title: widget.directory.name,
          onBack: _busy ? null : () => Navigator.pop(context),
          actions: [
            if (canCreate)
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
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView(
                    padding: settingsPagePadding(
                      context,
                      const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    ),
                    children: [
                      if (items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 32,
                            horizontal: 16,
                          ),
                          child: Text(
                            canCreate
                                ? '还没有工作树，点击右上角创建'
                                : '此目录尚无 Git 提交，提交后可创建工作树',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      for (final item in items.cast<Map>())
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: settingsFieldColor(context),
                            borderRadius: BorderRadius.circular(24),
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              contentPadding: const EdgeInsets.only(
                                left: 18,
                                right: 8,
                              ),
                              leading: const SettingsIcon(
                                type: SettingsIconType.git,
                              ),
                              title: Text(
                                item['name'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 15),
                              ),
                              subtitle: Text(
                                '基于 ${item['baseBranch']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                              onTap: _busy ? null : () => _act(item, 'diff'),
                              trailing: Builder(
                                builder: (anchor) => IconButton(
                                  tooltip: '工作树操作',
                                  icon: const SettingsIcon(
                                    type: SettingsIconType.more,
                                  ),
                                  onPressed: _busy
                                      ? null
                                      : () => _menu(anchor, item),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
