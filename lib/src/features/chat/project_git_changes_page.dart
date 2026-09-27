import 'package:flutter/material.dart';

import '../../app/glass_notice.dart';
import '../../app/ui_action.dart';
import '../../platform/aurai_platform.dart';
import 'app_confirmation_dialog.dart';
import 'attachment_action_icon.dart';
import 'delete_confirmation_dialog.dart';
import 'settings_appearance.dart';
import 'workspace_changes_view.dart';

class ProjectGitChangesPage extends StatefulWidget {
  const ProjectGitChangesPage.worktree({
    super.key,
    required this.projectId,
    required this.worktreeId,
    required this.worktreeName,
  }) : taskId = null;

  const ProjectGitChangesPage.task({
    super.key,
    required this.projectId,
    required this.taskId,
  }) : worktreeId = null,
       worktreeName = '本次任务';

  final String projectId;
  final String? worktreeId;
  final String? taskId;
  final String worktreeName;

  @override
  State<ProjectGitChangesPage> createState() => _ProjectGitChangesPageState();
}

class _ProjectGitChangesPageState extends State<ProjectGitChangesPage> {
  Map<String, Object?>? _data;
  bool _busy = false;

  Future<Map<String, Object?>> _invoke(
    String operation, [
    Map<String, Object?> arguments = const {},
  ]) => AuraiPlatform.instance.deviceExtension('projectDevelopmentOperation', {
    'projectId': widget.projectId,
    'operation': operation,
    'arguments': {
      if (widget.worktreeId != null) 'worktreeId': widget.worktreeId,
      if (widget.taskId != null) 'taskId': widget.taskId,
      ...arguments,
    },
  });

  String _operation(String worktree, String task) =>
      widget.taskId == null ? worktree : task;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() => runUiAction(context, () async {
    final data = await _invoke(
      _operation('getProjectWorktreeChanges', 'getProjectGitTaskChanges'),
    );
    if (mounted) setState(() => _data = data);
  });

  Future<void> _open(Map<String, Object?> change) async {
    await runUiAction(context, () async {
      final result = await _invoke(
        _operation('getProjectWorktreeFileDiff', 'getProjectGitTaskFileDiff'),
        {'path': change['path']},
      );
      if (!mounted) return;
      final restored = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => _ProjectGitFileDiffPage(
            path: change['path']! as String,
            diff: result['diff']! as String,
            truncated: result['truncated'] == true,
            actionLabel: change['reverted'] == true ? '重做这个文件' : '撤销这个文件',
            canAct: change['conflict'] != true,
            onAction: () => _restore(change, closeDetail: true),
          ),
        ),
      );
      if (restored == true && mounted) await _load();
    });
  }

  Future<bool> _restore(
    Map<String, Object?> change, {
    bool closeDetail = false,
  }) async {
    final redo = widget.taskId != null && change['reverted'] == true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => redo
          ? const AppConfirmationDialog(
              title: '重做这个文件？',
              description: '恢复本次任务对这个文件的修改。文件在撤销后又有其他修改时不会覆盖。',
              confirmLabel: '重做文件',
              regular: true,
            )
          : DeleteConfirmationDialog(
              title: '撤销这个文件？',
              description: widget.taskId == null
                  ? '恢复到工作树创建时的版本。这个文件在当前工作树中的修改会被丢弃。'
                  : '只回退本次任务对这个文件的修改。文件之后有其他修改时不会覆盖。',
              confirmLabel: '撤销文件',
            ),
    );
    if (confirmed != true || !mounted) return false;
    setState(() => _busy = true);
    var restored = false;
    await runUiAction(context, () async {
      await _invoke(
        redo
            ? 'redoProjectGitTaskFile'
            : _operation(
                'restoreProjectWorktreeFile',
                'restoreProjectGitTaskFile',
              ),
        {'path': change['path'], 'oldPath': change['oldPath']},
      );
      restored = true;
      if (closeDetail && mounted) Navigator.pop(context, true);
    });
    if (mounted) setState(() => _busy = false);
    return restored;
  }

  Future<void> _discardAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => DeleteConfirmationDialog(
        title: '撤销全部修改？',
        description: widget.taskId == null
            ? '工作树会恢复到创建时的 Git 提交，之后的提交、未提交修改和未跟踪文件都会被丢弃。'
            : '只撤销本次任务记录的文件修改，不移动当前分支，也不覆盖这些文件之后产生的修改。',
        confirmLabel: '全部撤销',
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    await runUiAction(context, () async {
      await _invoke(
        _operation(
          'discardProjectWorktreeChanges',
          'discardProjectGitTaskChanges',
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showGlassSnackBar(const SnackBar(content: Text('已撤销全部修改')));
      await _load();
    });
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _redoAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const AppConfirmationDialog(
        title: '重做全部修改？',
        description: '恢复最近一次任务中已撤销的文件修改。文件在撤销后又有其他修改时不会覆盖。',
        confirmLabel: '全部重做',
        regular: true,
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    await runUiAction(context, () async {
      await _invoke('redoProjectGitTaskChanges');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showGlassSnackBar(const SnackBar(content: Text('已重做全部修改')));
      await _load();
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final available = data?['available'] != false;
    final changes = data == null || data['available'] == false
        ? const <Map<String, Object?>>[]
        : (data['changes'] as List)
              .cast<Map>()
              .map((item) => item.cast<String, Object?>())
              .toList();
    final hasConflict = changes.any((change) => change['conflict'] == true);
    final hasPending = changes.any((change) => change['reverted'] != true);
    final hasReverted = changes.any((change) => change['reverted'] == true);
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: SettingsAppBar(
          title: widget.taskId == null ? '工作树改动' : '任务改动',
          onBack: _busy ? null : () => Navigator.pop(context),
        ),
        body: data == null
            ? const SizedBox.shrink()
            : !available
            ? const Center(child: Text('仅保留最近一次修改任务的撤销记录'))
            : changes.isEmpty
            ? const Center(child: Text('没有修改'))
            : ListView(
                padding: settingsPagePadding(
                  context,
                  const EdgeInsets.fromLTRB(16, 12, 16, 112),
                ),
                children: [
                  Text(
                    '${widget.worktreeName} · ${changes.length} 个文件',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  WorkspaceLineCounts((
                    added: data['addedLines']! as int,
                    removed: data['removedLines']! as int,
                  )),
                  const SizedBox(height: 16),
                  for (final change in changes) ...[
                    _GitChangeTile(
                      change: change,
                      onTap: _busy ? null : () => _open(change),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
        bottomNavigationBar: !available || changes.isEmpty
            ? null
            : SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.taskId != null && hasReverted) ...[
                      TextButton(
                        onPressed: _busy || hasConflict ? null : _redoAll,
                        style: TextButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('重做已撤销的修改'),
                      ),
                      if (hasPending) const SizedBox(height: 8),
                    ],
                    if (hasPending || widget.taskId == null)
                      TextButton(
                        onPressed: _busy || !hasPending || hasConflict
                            ? null
                            : _discardAll,
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.errorContainer,
                          minimumSize: const Size.fromHeight(48),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          hasConflict
                              ? '文件之后有修改，无法全部撤销'
                              : hasPending
                              ? '撤销全部修改'
                              : '已撤销全部修改',
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _GitChangeTile extends StatelessWidget {
  const _GitChangeTile({required this.change, required this.onTap});

  final Map<String, Object?> change;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = switch (change['status']) {
      'add' => '新增',
      'delete' => '删除',
      'rename' => '重命名',
      'copy' => '复制',
      _ => '修改',
    };
    final reverted = change['reverted'] == true;
    final conflict = change['conflict'] == true;
    return Material(
      color: settingsFieldColor(context),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              AttachmentActionIcon(
                type: AttachmentActionIconType.file,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(change['path']! as String),
                    if (change['oldPath'] case final String oldPath) ...[
                      const SizedBox(height: 3),
                      Text(
                        '原路径 $oldPath',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    reverted
                        ? '已撤销'
                        : conflict
                        ? '之后有修改'
                        : status,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  WorkspaceLineCounts((
                    added: change['addedLines']! as int,
                    removed: change['removedLines']! as int,
                  )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectGitFileDiffPage extends StatelessWidget {
  const _ProjectGitFileDiffPage({
    required this.path,
    required this.diff,
    required this.truncated,
    required this.actionLabel,
    required this.canAct,
    required this.onAction,
  });

  final String path;
  final String diff;
  final bool truncated;
  final String actionLabel;
  final bool canAct;
  final Future<bool> Function() onAction;

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: SettingsAppBar(
      title: path.split('/').last,
      onBack: () => Navigator.pop(context),
    ),
    body: SingleChildScrollView(
      padding: settingsPagePadding(
        context,
        const EdgeInsets.fromLTRB(16, 12, 16, 112),
      ),
      child: SelectableText(
        '$diff${truncated ? '\n\n改动较多，仅显示部分内容。' : ''}',
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: TextButton(
        onPressed: canAct ? onAction : null,
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          minimumSize: const Size.fromHeight(48),
          shape: const StadiumBorder(),
        ),
        child: Text(canAct ? actionLabel : '文件之后有修改'),
      ),
    ),
  );
}
