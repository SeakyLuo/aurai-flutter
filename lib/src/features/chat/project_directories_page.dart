import 'app_bottom_sheet.dart';
import '../../widgets/empty_data_view.dart';
import 'package:flutter/material.dart';
import '../../app/ui_action.dart';
import '../../domain/agent_models.dart';
import '../../platform/aurai_platform.dart';
import '../../storage/development_projects.dart';
import '../../storage/project_directories.dart';
import '../../storage/project_directory.dart';
import 'chat_controller.dart';
import 'project_directory_sheet.dart';
import 'conversation_menu_icon.dart';
import 'app_confirmation_dialog.dart';
import 'dialog_action_button.dart';
import 'file_tool_icon.dart';
import 'header_action_menu.dart';
import 'project_worktrees_page.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class ProjectDirectoriesPage extends StatefulWidget {
  const ProjectDirectoriesPage({
    super.key,
    required this.controller,
    required this.project,
  });
  final ChatController controller;
  final DevelopmentProject project;
  @override
  State<ProjectDirectoriesPage> createState() => _ProjectDirectoriesPageState();
}

class _ProjectDirectoriesPageState extends State<ProjectDirectoriesPage> {
  List<ProjectDirectory>? _items;
  bool _busy = false;
  ProjectDirectories get _store =>
      ProjectDirectories(widget.controller.groupStore.database);
  Future<void> _load() => runUiAction(context, () async {
    final items = await _store.list(widget.project);
    if (mounted) setState(() => _items = items);
  }).then((_) {});
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _add() async {
    final selection =
        await showAppBottomSheet<(String?, List<ProjectDirectory>)>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: false,
          barrierColor: Colors.black.withValues(alpha: .24),
          builder: (_) => ProjectDirectorySheet(
            excluded: _items!.map((item) => item.uri).toSet(),
          ),
        );
    if (selection == null || !mounted) return;
    final name = selection.$1;
    setState(() => _busy = true);
    await runUiAction(context, () async {
      widget.controller.requireProjectIdle(widget.project.id);
      final directories = [...selection.$2];
      if (name != null) {
        final result = await AuraiPlatform.instance.deviceExtension(
          'createManagedProject',
          {'id': newMessageId(), 'name': name},
        );
        directories.add(
          ProjectDirectory(uri: result['uri'] as String, name: name),
        );
      }
      await _store.addAll(widget.project, directories);
      await _load();
    });
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  Future<void> _detach(ProjectDirectory directory) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AppConfirmationDialog(
        title: '取消关联此目录？',
        description: '项目成员 将不再访问此目录。文件和其他项目的关联保留。',
        confirmLabel: '取消关联',
        confirmRole: DialogActionRole.destructive,
      ),
    );
    if (confirmed != true || !mounted) return;
    await runUiAction(context, () async {
      widget.controller.requireProjectIdle(widget.project.id);
      await _store.detach(widget.project, directory.uri);
      await _load();
    });
  }

  Future<void> _worktrees(ProjectDirectory directory) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectWorktreesPage(
          controller: widget.controller,
          project: widget.project,
          directory: directory,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _actions(BuildContext anchor, ProjectDirectory directory) async {
    Map<String, Object?>? repository;
    if (directory.managed && !directory.worktree) {
      final loaded = await runUiAction(context, () async {
        repository = await AuraiPlatform.instance
            .deviceExtension('projectDevelopmentOperation', {
              'projectId': directory.workspaceId,
              'operation': 'listProjectWorktrees',
              'arguments': <String, Object?>{},
            });
      });
      if (!loaded || !mounted || !anchor.mounted) return;
    }
    final action = await showHeaderActionMenu(
      anchor,
      destructiveValues: const {'detach'},
      items: [
        if (repository?['available'] == true)
          (
            value: 'worktrees',
            label: '管理工作树',
            icon: const SettingsIcon(type: SettingsIconType.git),
          ),
        (
          value: 'detach',
          label: '取消关联',
          icon: const ConversationMenuIcon(
            type: ConversationMenuIconType.delete,
          ),
        ),
      ],
    );
    if (!mounted) return;
    if (action == 'worktrees') await _worktrees(directory);
    if (action == 'detach') await _detach(directory);
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: SettingsAppBar(
          title: '项目目录',
          onBack: _busy ? null : () => Navigator.pop(context),
          actions: [
            Builder(
              builder: (anchor) => SettingsGlassAction(
                label: '添加目录',
                icon: Icons.add_rounded,
                iconWidget: const SettingsIcon(type: SettingsIconType.add),
                onPressed: _busy || _items == null ? null : _add,
              ),
            ),
          ],
        ),
        body: items != null && items.isEmpty
            ? Padding(
                padding: settingsPagePadding(context, EdgeInsets.zero),
                child: const EmptyDataView(title: '还没有关联目录，点击右上角添加。'),
              )
            : ListView(
                padding: settingsPagePadding(
                  context,
                  const EdgeInsets.fromLTRB(16, 12, 16, 24),
                ),
                children: [
                  if (items == null)
                    const Center(child: CircularProgressIndicator()),
                  for (final item in items ?? <ProjectDirectory>[])
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
                          leading: const FileToolIcon(
                            type: FileToolIconType.folder,
                          ),
                          title: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15),
                          ),
                          subtitle: Text(
                            item.worktree
                                ? 'Git 工作树'
                                : item.managed
                                ? 'Aurai 工作区'
                                : '手机文件夹',
                          ),
                          subtitleTextStyle: TextStyle(
                            fontSize: 13,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          trailing: Builder(
                            builder: (anchor) => IconButton(
                              tooltip: '目录操作',
                              icon: const SettingsIcon(
                                type: SettingsIconType.more,
                              ),
                              onPressed: _busy
                                  ? null
                                  : () => _actions(anchor, item),
                            ),
                          ),
                          onTap: _busy
                              ? null
                              : () => runUiAction(
                                  context,
                                  () => AuraiPlatform.instance
                                      .openProjectFolder(item.uri),
                                ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
