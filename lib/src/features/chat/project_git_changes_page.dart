import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/glass_notice.dart';
import '../../app/ui_action.dart';
import '../../platform/aurai_platform.dart';
import 'app_confirmation_dialog.dart';
import 'delete_confirmation_dialog.dart';
import 'git_diff_view.dart';
import 'glass_surface.dart';
import 'header_action_menu.dart';
import 'question_icon.dart';
import 'search_skeleton.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'workspace_changes_view.dart';

enum _ProjectChangesAction { redoAll, discardAll }

class ProjectGitChangesPage extends StatefulWidget {
  const ProjectGitChangesPage.worktree({
    super.key,
    required this.projectId,
    required this.worktreeId,
    required this.worktreeName,
  }) : taskId = null,
       initialData = null;

  const ProjectGitChangesPage.task({
    super.key,
    required this.projectId,
    required this.taskId,
    this.initialData,
  }) : worktreeId = null,
       worktreeName = '本次任务';

  final String projectId;
  final String? worktreeId;
  final String? taskId;
  final String worktreeName;
  final Map<String, Object?>? initialData;

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
    _data = widget.initialData;
    if (_data == null) _load();
  }

  Future<void> _load() => runUiAction(context, () async {
    final data = await _invoke(
      _operation('getProjectWorktreeChanges', 'getProjectGitTaskChanges'),
    );
    if (mounted) setState(() => _data = data);
  });

  Future<void> _open(Map<String, Object?> change) async {
    final restored = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectGitFileDiffPage.load(
          path: change['path']! as String,
          loader: () => _invoke(
            _operation(
              'getProjectWorktreeFileDiff',
              'getProjectGitTaskFileDiff',
            ),
            {'path': change['path']},
          ),
          actionLabel: change['reverted'] == true ? '重做这个文件' : '撤销这个文件',
          canAct: change['conflict'] != true,
          onAction: () => _restore(change, closeDetail: true),
        ),
      ),
    );
    if (restored == true && mounted) await _load();
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

  Future<void> _showActions(
    Offset position, {
    required bool canRedo,
    required bool canDiscard,
  }) async {
    final action = await showGeneralDialog<_ProjectChangesAction>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭改动菜单',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, animation, _) {
        final media = MediaQuery.of(dialogContext);
        final width = math.min(
          212.0,
          media.size.width - media.padding.horizontal - 16,
        );
        final itemCount = (canRedo ? 1 : 0) + (canDiscard ? 1 : 0);
        final height = itemCount * 54.0 + 14;
        final left = (position.dx - width)
            .clamp(
              media.padding.left + 8,
              media.size.width - media.padding.right - width - 8,
            )
            .toDouble();
        final top = position.dy
            .clamp(
              media.padding.top + 8,
              math.max(
                media.padding.top + 8,
                media.size.height - media.padding.bottom - height - 8,
              ),
            )
            .toDouble();
        final color = Theme.of(dialogContext).colorScheme.onSurface;
        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              width: width,
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
                child: GlassSurface(
                  radius: 24,
                  child: Material(
                    type: MaterialType.transparency,
                    child: Padding(
                      padding: const EdgeInsets.all(7),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (canRedo)
                            _ProjectChangesActionTile(
                              label: '重做全部修改',
                              iconColor: color,
                              onTap: () => Navigator.pop(
                                dialogContext,
                                _ProjectChangesAction.redoAll,
                              ),
                            ),
                          if (canDiscard)
                            _ProjectChangesActionTile(
                              label: '撤销全部修改',
                              iconColor: color,
                              onTap: () => Navigator.pop(
                                dialogContext,
                                _ProjectChangesAction.discardAll,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    switch (action) {
      case _ProjectChangesAction.redoAll:
        await _redoAll();
      case _ProjectChangesAction.discardAll:
        await _discardAll();
      case null:
        break;
    }
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
          actions: [
            if (!_busy &&
                !hasConflict &&
                (hasPending || (widget.taskId != null && hasReverted)))
              Builder(
                builder: (buttonContext) => SettingsGlassAction(
                  label: '更多',
                  icon: Icons.more_vert_rounded,
                  onPressed: () {
                    final box = buttonContext.findRenderObject()! as RenderBox;
                    _showActions(
                      box.localToGlobal(
                        Offset(box.size.width, box.size.height),
                      ),
                      canRedo: widget.taskId != null && hasReverted,
                      canDiscard: hasPending,
                    );
                  },
                ),
              ),
          ],
        ),
        body: data == null
            ? ListView(
                physics: const NeverScrollableScrollPhysics(),
                padding: settingsPagePadding(
                  context,
                  const EdgeInsets.fromLTRB(20, 16, 20, 24),
                ),
                children: const [
                  SearchSkeleton(
                    label: '正在加载任务改动',
                    avatarSize: 40,
                    rowGap: 20,
                    rowCount: 6,
                  ),
                ],
              )
            : !available
            ? const Center(child: Text('仅保留最近一次修改任务的撤销记录'))
            : changes.isEmpty
            ? const Center(child: Text('没有修改'))
            : ListView.builder(
                padding: settingsPagePadding(
                  context,
                  const EdgeInsets.fromLTRB(16, 12, 16, 112),
                ),
                itemCount: changes.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.worktreeName} · ${changes.length} 个文件',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
                          WorkspaceLineCounts((
                            added: data['addedLines']! as int,
                            removed: data['removedLines']! as int,
                          )),
                        ],
                      ),
                    );
                  }
                  final change = changes[index - 1];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _GitChangeTile(
                      change: change,
                      onTap: _busy ? null : () => _open(change),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _ProjectChangesActionTile extends StatelessWidget {
  const _ProjectChangesActionTile({
    required this.label,
    required this.iconColor,
    required this.onTap,
  });

  final String label;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(17),
    onTap: onTap,
    child: SizedBox(
      height: 54,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            QuestionIcon(type: QuestionIconType.undo, color: iconColor),
            const SizedBox(width: 13),
            Text(label, style: const TextStyle(fontSize: 15)),
          ],
        ),
      ),
    ),
  );
}

class _GitChangeTile extends StatelessWidget {
  const _GitChangeTile({required this.change, required this.onTap});

  final Map<String, Object?> change;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WorkspaceFilePathText(change['path']! as String),
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
                  if (reverted || conflict) ...[
                    Text(
                      reverted ? '已撤销' : '之后有修改',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
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

class ProjectGitFileDiffPage extends StatefulWidget {
  const ProjectGitFileDiffPage({
    required this.path,
    required this.diff,
    required this.truncated,
    required this.actionLabel,
    required this.canAct,
    required this.onAction,
    super.key,
  }) : loader = null;

  const ProjectGitFileDiffPage.load({
    required this.path,
    required this.loader,
    required this.actionLabel,
    required this.canAct,
    required this.onAction,
    super.key,
  }) : diff = null,
       truncated = false;

  final String path;
  final String? diff;
  final bool truncated;
  final String actionLabel;
  final bool canAct;
  final Future<bool> Function() onAction;
  final Future<Map<String, Object?>> Function()? loader;

  @override
  State<ProjectGitFileDiffPage> createState() => _ProjectGitFileDiffPageState();
}

class _ProjectGitFileDiffPageState extends State<ProjectGitFileDiffPage> {
  String? _diff;
  late bool _truncated;
  bool _busy = false;
  bool _wrapLines = true;

  @override
  void initState() {
    super.initState();
    _diff = widget.diff;
    _truncated = widget.truncated;
    if (widget.loader != null) _load();
  }

  Future<void> _load() async {
    final loaded = await runUiAction(context, () async {
      final result = await widget.loader!();
      if (!mounted) return;
      setState(() {
        _diff = result['diff']! as String;
        _truncated = result['truncated'] == true;
      });
    });
    if (!loaded && mounted) Navigator.pop(context);
  }

  Future<void> _act() async {
    setState(() => _busy = true);
    await widget.onAction();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _showViewOptions(BuildContext buttonContext) async {
    final mode = await showHeaderActionMenu(
      buttonContext,
      items: [
        (
          value: 'wrap',
          label: '自动换行',
          icon: _wrapLines
              ? const SettingsIcon(type: SettingsIconType.check)
              : const SizedBox.square(dimension: 24),
        ),
        (
          value: 'scroll',
          label: '横向滚动',
          icon: !_wrapLines
              ? const SettingsIcon(type: SettingsIconType.check)
              : const SizedBox.square(dimension: 24),
        ),
      ],
    );
    if (mode == null || !mounted) return;
    setState(() => _wrapLines = mode == 'wrap');
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _diff != null && widget.canAct && !_busy;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: SettingsAppBar(
          title: widget.path.split('/').last,
          onBack: _busy ? null : () => Navigator.pop(context),
          actions: [
            SettingsGlassActionSurface(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RoundAction(
                    label: widget.canAct ? widget.actionLabel : '文件之后有修改',
                    icon: Icons.undo_rounded,
                    iconWidget: QuestionIcon(
                      type: QuestionIconType.undo,
                      color: SettingsGlassAction.foregroundColor(
                        context,
                        enabled: enabled,
                      ),
                    ),
                    onPressed: enabled ? _act : null,
                  ),
                  SizedBox(
                    height: 18,
                    child: VerticalDivider(
                      width: 1,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  Builder(
                    builder: (buttonContext) => RoundAction(
                      label: '显示设置',
                      icon: Icons.more_vert_rounded,
                      iconWidget: const SettingsIcon(
                        type: SettingsIconType.more,
                      ),
                      onPressed: () => _showViewOptions(buttonContext),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: _diff == null
            ? Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            : GitDiffView(
                diff: _diff!,
                truncated: _truncated,
                wrapLines: _wrapLines,
              ),
      ),
    );
  }
}
