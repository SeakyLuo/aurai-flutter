import '../../domain/tool_activity_groups.dart';
import 'dart:convert';
import '../../domain/workspace_file_changes.dart';
import 'workspace_changes_view.dart';
import 'tool_activity_group.dart';
import 'markdown_link_underlines.dart';
import 'task_elapsed.dart';
import 'cjk_strong_syntax.dart';
import 'package:flutter/material.dart';
import '../../app/global_ui.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../domain/agent_models.dart';
import '../../domain/web_sources.dart';
import '../../domain/source_reference.dart';
import 'tool_activity_view.dart';
import 'chat_scroll_anchor.dart';
import 'source_citation_syntax.dart';
import 'source_citation_view.dart';
import 'project_git_changes_page.dart';

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
          if (widget.summary.gitChanges case final gitChanges?)
            Column(
              children: [
                for (final change
                    in gitChanges.directories.isEmpty
                        ? [gitChanges]
                        : gitChanges.directories)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (change.directoryName != null)
                        Text(change.directoryName!),
                      _GitTaskChangesCard(changes: change),
                    ],
                  ),
              ],
            ),
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

class _GitTaskChangesCard extends StatelessWidget {
  const _GitTaskChangesCard({required this.changes});

  final ProjectGitTaskChanges changes;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => ProjectGitChangesPage.task(
              projectId: changes.workspaceId,
              taskId: changes.taskId,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(child: Text('已编辑 ${changes.fileCount} 个文件')),
              WorkspaceLineCounts((
                added: changes.addedLines,
                removed: changes.removedLines,
              )),
            ],
          ),
        ),
      ),
    ),
  );
}
