import '../../domain/tool_activity_groups.dart';
import 'dart:convert';
import 'dart:math' as math;
import '../../domain/workspace_file_changes.dart';
import 'workspace_changes_view.dart';
import 'tool_activity_group.dart';
import 'markdown_link_underlines.dart';
import 'task_elapsed.dart';
import 'cjk_strong_syntax.dart';
import 'package:flutter/material.dart';
import '../../app/global_ui.dart';
import '../../app/glass_notice.dart';
import '../../app/ui_action.dart';
import '../../platform/aurai_platform.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../domain/agent_models.dart';
import '../../domain/web_sources.dart';
import '../../domain/source_reference.dart';
import 'tool_activity_view.dart';
import 'chat_scroll_anchor.dart';
import 'source_citation_syntax.dart';
import 'source_citation_view.dart';
import 'project_git_changes_page.dart';
import 'app_confirmation_dialog.dart';
import 'delete_confirmation_dialog.dart';
import 'attachment_action_icon.dart';
import 'html_message_more_button.dart';
import 'glass_surface.dart';
import 'question_icon.dart';

enum _GitChangeAction { review, changeAll }

class TaskSummaryView extends StatefulWidget {
  const TaskSummaryView({
    super.key,
    required this.summary,
    required this.messageId,
    required this.onOpenLink,
    this.excludedMessageId,
  });

  final AgentTaskSummary summary;
  final String? excludedMessageId;
  final String messageId;
  String get storageId => 'task-expanded:$messageId';
  final ValueChanged<String?> onOpenLink;

  @override
  State<TaskSummaryView> createState() => _TaskSummaryViewState();
}

class _TaskSummaryViewState extends State<TaskSummaryView> {
  late bool _expanded;
  List<Widget>? _activityWidgets;
  WorkspaceFileChanges? _fileChanges;
  Iterable<String?> _otherFileResults() sync* {
    final changes = widget.summary.gitChanges;
    final reviewedRoots = {
      if (changes != null)
        for (final directory
            in changes.directories.isEmpty ? [changes] : changes.directories)
          'aurai://project/${directory.workspaceId}',
    };
    for (final activity in widget.summary.activities) {
      final result = activity.resultJson;
      if (result == null) continue;
      final output = jsonDecode(result) as Map;
      if (!reviewedRoots.contains(output['workspaceRoot'])) yield result;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _activityWidgets = null;
    _expanded =
        PageStorage.of(context).readState(context, identifier: widget.storageId)
            as bool? ??
        widget.summary.stopped;
  }

  @override
  void didUpdateWidget(TaskSummaryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.summary, widget.summary)) {
      _activityWidgets = null;
      _fileChanges = null;
    }
    if (oldWidget.excludedMessageId != widget.excludedMessageId)
      _activityWidgets = null;
    if (!oldWidget.summary.stopped && widget.summary.stopped) {
      _expanded = true;
      PageStorage.of(
        context,
      ).writeState(context, true, identifier: widget.storageId);
    }
  }

  String get _duration =>
      taskDuration(Duration(milliseconds: widget.summary.elapsedMilliseconds));

  String get _heading {
    if (!widget.summary.isTask) {
      return widget.summary.stopped ? '思考已停止' : '思考过程';
    }
    return widget.summary.stopped ? '用时 $_duration · 已停止' : '用时 $_duration';
  }

  @override
  Widget build(BuildContext context) {
    final sources = _expanded && _activityWidgets == null
        ? webSourcesFromActivities(widget.summary.activities)
        : const <String, SourceReference>{};
    Widget activityAt(int index) {
      final activity = widget.summary.activities[index];
      if (widget.excludedMessageId != null &&
          activity.messageId == widget.excludedMessageId) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: EdgeInsets.symmetric(
          vertical: activity.status == null ? 9 : 5,
        ),
        child: activity.status == null
            ? MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                child: SelectionArea(
                  child: MarkdownLinkUnderlines(
                    child: MarkdownBody(
                      inlineSyntaxes: [
                        SourceCitationSyntax(sources),
                        SourceLinkSyntax(sources),
                        CjkStrongSyntax(),
                      ],
                      builders: {
                        'source-citation': SourceCitationBuilder(
                          onOpenLink: widget.onOpenLink,
                        ),
                      },
                      data: activity.text,
                      selectable: false,
                      onTapLink: (text, href, title) => widget.onOpenLink(href),
                      styleSheet:
                          MarkdownStyleSheet.fromTheme(
                            Theme.of(context),
                          ).copyWith(
                            a: GlobalUI.linkStyle(context),
                            horizontalRuleDecoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  width: 0.5,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant,
                                ),
                              ),
                            ),
                            tableColumnWidth: const IntrinsicColumnWidth(),
                            tableScrollbarThumbVisibility: true,
                            tablePadding: const EdgeInsets.only(bottom: 12),
                            p: TextStyle(
                              fontSize: activity.isReasoning ? 15 : 16,
                              height: 1.65,
                              color: activity.isReasoning
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                    ),
                  ),
                ),
              )
            : ToolActivityView(
                showFileChanges: false,
                storageId: '${widget.messageId}:$index',
                title: activity.text,
                toolName: activity.toolName,
                status: activity.status!,
                requestJson: activity.requestJson,
                resultJson: activity.resultJson,
              ),
      );
    }

    final groups = toolActivityGroups([
      for (final activity in widget.summary.activities)
        activity.status == null ? null : activity.toolName,
    ]);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _expanded,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                ChatScrollAnchor.beforeResize(context);
                setState(() => _expanded = !_expanded);
                PageStorage.of(
                  context,
                ).writeState(context, _expanded, identifier: widget.storageId);
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        _heading,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: _expanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeInOutCubic,
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 12),
          WorkspaceChangesView(
            changes: _fileChanges ??= WorkspaceFileChanges.fromResults(
              _otherFileResults(),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _activityWidgets ??= [
                  for (final group in groups)
                    if (group.end - group.start == 1)
                      activityAt(group.start)
                    else
                      ToolActivityGroup(
                        key: ValueKey('${widget.messageId}:${group.start}'),
                        storageId: '${widget.messageId}:${group.start}',
                        toolName:
                            widget.summary.activities[group.start].toolName!,
                        statuses: [
                          for (var i = group.start; i < group.end; i++)
                            widget.summary.activities[i].status!,
                        ],
                        children: [
                          for (var i = group.start; i < group.end; i++)
                            activityAt(i),
                        ],
                      ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class GitTaskChangesView extends StatelessWidget {
  const GitTaskChangesView({super.key, required this.changes});

  final ProjectGitTaskChanges changes;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final change
            in changes.directories.isEmpty ? [changes] : changes.directories)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _GitTaskChangesCard(changes: change),
          ),
      ],
    ),
  );
}

class _GitTaskChangesCard extends StatefulWidget {
  const _GitTaskChangesCard({required this.changes});

  final ProjectGitTaskChanges changes;

  @override
  State<_GitTaskChangesCard> createState() => _GitTaskChangesCardState();
}

class _GitTaskChangesCardState extends State<_GitTaskChangesCard> {
  Map<String, Object?>? _data;
  bool _busy = false;

  Future<Map<String, Object?>> _invoke(
    String operation, [
    Map<String, Object?> arguments = const {},
  ]) => AuraiPlatform.instance.deviceExtension('projectDevelopmentOperation', {
    'projectId': widget.changes.workspaceId,
    'operation': operation,
    'arguments': {'taskId': widget.changes.taskId, ...arguments},
  });

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() => runUiAction(context, () async {
    final data = await _invoke('getProjectGitTaskChanges');
    if (mounted) setState(() => _data = data);
  });

  Future<void> _review() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectGitChangesPage.task(
          projectId: widget.changes.workspaceId,
          taskId: widget.changes.taskId,
          initialData: _data,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openFile(Map<String, Object?> file) async {
    final restored = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectGitFileDiffPage.load(
          path: file['path']! as String,
          loader: () =>
              _invoke('getProjectGitTaskFileDiff', {'path': file['path']}),
          actionLabel: file['reverted'] == true ? '重做这个文件' : '撤销这个文件',
          canAct: file['conflict'] != true,
          onAction: () => _restoreFile(file),
        ),
      ),
    );
    if (restored == true && mounted) await _load();
  }

  Future<bool> _restoreFile(Map<String, Object?> file) async {
    final redo = file['reverted'] == true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => redo
          ? const AppConfirmationDialog(
              title: '重做这个文件？',
              description: '恢复本次任务对这个文件的修改。文件在撤销后又有其他修改时不会覆盖。',
              confirmLabel: '重做文件',
              regular: true,
            )
          : const DeleteConfirmationDialog(
              title: '撤销这个文件？',
              description: '只回退本次任务对这个文件的修改。文件之后有其他修改时不会覆盖。',
              confirmLabel: '撤销文件',
            ),
    );
    if (confirmed != true || !mounted) return false;
    setState(() => _busy = true);
    var restored = false;
    await runUiAction(context, () async {
      await _invoke(
        redo ? 'redoProjectGitTaskFile' : 'restoreProjectGitTaskFile',
        {'path': file['path'], 'oldPath': file['oldPath']},
      );
      restored = true;
      if (mounted) Navigator.pop(context, true);
    });
    if (mounted) setState(() => _busy = false);
    return restored;
  }

  Future<void> _showActions({
    required Offset position,
    required bool canChange,
    required bool redo,
  }) async {
    final action = await showGeneralDialog<_GitChangeAction>(
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
        final itemCount = canChange ? 2 : 1;
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
                          SizedBox(
                            height: 54,
                            child: _GitChangeActionTile(
                              icon: AttachmentActionIcon(
                                type: AttachmentActionIconType.file,
                                color: color,
                              ),
                              label: '审核改动',
                              onTap: () => Navigator.pop(
                                dialogContext,
                                _GitChangeAction.review,
                              ),
                            ),
                          ),
                          if (canChange)
                            SizedBox(
                              height: 54,
                              child: _GitChangeActionTile(
                                icon: QuestionIcon(
                                  type: QuestionIconType.undo,
                                  color: color,
                                ),
                                label: redo ? '重做全部修改' : '撤销全部修改',
                                onTap: () => Navigator.pop(
                                  dialogContext,
                                  _GitChangeAction.changeAll,
                                ),
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
      case _GitChangeAction.review:
        await _review();
      case _GitChangeAction.changeAll:
        await _changeAll(redo: redo);
      case null:
        break;
    }
  }

  Future<void> _changeAll({required bool redo}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => redo
          ? const AppConfirmationDialog(
              title: '重做全部修改？',
              description: '恢复本次任务中已撤销的文件修改。文件在撤销后又有其他修改时不会覆盖。',
              confirmLabel: '全部重做',
              regular: true,
            )
          : const DeleteConfirmationDialog(
              title: '撤销全部修改？',
              description: '只撤销本次任务记录的文件修改，不移动当前分支，也不覆盖这些文件之后产生的修改。',
              confirmLabel: '全部撤销',
            ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    await runUiAction(context, () async {
      await _invoke(
        redo ? 'redoProjectGitTaskChanges' : 'discardProjectGitTaskChanges',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showGlassSnackBar(
        SnackBar(content: Text(redo ? '已重做全部修改' : '已撤销全部修改')),
      );
      await _load();
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = dark ? const Color(0xff232323) : Colors.white;
    final insetColor = dark ? const Color(0xff181818) : const Color(0xfff3f3f3);
    final borderColor = dark
        ? const Color(0xff3a3a3a)
        : const Color(0xffe3e3e3);
    final data = _data;
    final available = data?['available'] != false;
    final previewFiles = [
      for (final file in widget.changes.previewFiles)
        <String, Object?>{
          'path': file.path,
          'oldPath': file.oldPath,
          'addedLines': file.addedLines,
          'removedLines': file.removedLines,
          'reverted': false,
          'conflict': false,
        },
    ];
    final files = data == null || !available
        ? previewFiles
        : (data['changes'] as List)
              .cast<Map>()
              .map((item) => item.cast<String, Object?>())
              .toList();
    final hasConflict = files.any((file) => file['conflict'] == true);
    final hasPending = files.any((file) => file['reverted'] != true);
    final allReverted = files.isNotEmpty && !hasPending;
    final canChange =
        data != null && available && files.isNotEmpty && !hasConflict;
    final added = data?['addedLines'] as int? ?? widget.changes.addedLines;
    final removed =
        data?['removedLines'] as int? ?? widget.changes.removedLines;
    final editedTarget = files.length == 1
        ? (files.single['path']! as String).split('/').last
        : '${widget.changes.fileCount} 个文件';
    return Material(
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: insetColor,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: AttachmentActionIcon(
                          type: AttachmentActionIconType.file,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${allReverted ? '已撤销' : '已编辑'} $editedTarget',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            WorkspaceLineCounts((
                              added: added,
                              removed: removed,
                            )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Builder(
                  builder: (buttonContext) => HtmlMessageMoreButton(
                    onPressed: () {
                      if (_busy) return;
                      final box =
                          buttonContext.findRenderObject()! as RenderBox;
                      _showActions(
                        position: box.localToGlobal(
                          Offset(box.size.width, box.size.height),
                        ),
                        canChange: canChange,
                        redo: allReverted,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          if (files.isNotEmpty) ...[
            Divider(height: 1, color: borderColor),
            for (final file in files.take(3))
              InkWell(
                onTap: _busy || !available ? null : () => _openFile(file),
                splashColor: colors.onSurface.withValues(alpha: .06),
                highlightColor: colors.onSurface.withValues(alpha: .03),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: WorkspaceFilePathText(file['path']! as String),
                      ),
                      const SizedBox(width: 12),
                      WorkspaceLineCounts((
                        added: file['addedLines']! as int,
                        removed: file['removedLines']! as int,
                      )),
                    ],
                  ),
                ),
              ),
            if (widget.changes.fileCount > 3)
              InkWell(
                onTap: _busy ? null : _review,
                splashColor: colors.onSurface.withValues(alpha: .06),
                highlightColor: colors.onSurface.withValues(alpha: .03),
                child: Container(
                  color: insetColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Text(
                    '查看其余 ${widget.changes.fileCount - 3} 个文件',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurface,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _GitChangeActionTile extends StatelessWidget {
  const _GitChangeActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SizedBox.square(dimension: 24, child: FittedBox(child: icon)),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
        ],
      ),
    ),
  );
}
