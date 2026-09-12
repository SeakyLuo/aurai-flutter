import 'task_elapsed.dart';
import 'cjk_strong_syntax.dart';
import 'package:flutter/material.dart';
import '../../app/global_ui.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../domain/agent_models.dart';
import 'tool_activity_view.dart';
import 'chat_scroll_anchor.dart';

class TaskSummaryView extends StatefulWidget {
  const TaskSummaryView({
    super.key,
    required this.summary,
    required this.messageId,
    required this.onOpenLink,
  });

  final AgentTaskSummary summary;
  final String messageId;
  String get storageId => 'task-expanded:$messageId';
  final ValueChanged<String?> onOpenLink;

  @override
  State<TaskSummaryView> createState() => _TaskSummaryViewState();
}

class _TaskSummaryViewState extends State<TaskSummaryView> {
  late bool _expanded;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _expanded =
        PageStorage.of(context).readState(context, identifier: widget.storageId)
            as bool? ??
        widget.summary.stopped;
  }

  @override
  void didUpdateWidget(TaskSummaryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.summary.stopped && widget.summary.stopped) {
      _expanded = true;
      PageStorage.of(
        context,
      ).writeState(context, true, identifier: widget.storageId);
    }
  }

  String get _duration =>
      taskDuration(Duration(milliseconds: widget.summary.elapsedMilliseconds));

  @override
  Widget build(BuildContext context) {
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
                        widget.summary.stopped
                            ? '用时 $_duration · 已停止'
                            : '用时 $_duration',
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
          if (_expanded)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, activity)
                      in widget.summary.activities.indexed)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: activity.status == null ? 9 : 5,
                      ),
                      child: activity.status == null
                          ? MediaQuery.removePadding(
                              context: context,
                              removeBottom: true,
                              child: MarkdownBody(
                                inlineSyntaxes: [CjkStrongSyntax()],
                                data: activity.text,
                                selectable: true,
                                onTapLink: (text, href, title) =>
                                    widget.onOpenLink(href),
                                styleSheet:
                                    MarkdownStyleSheet.fromTheme(
                                      Theme.of(context),
                                    ).copyWith(
                                      a: TextStyle(
                                        color: GlobalUI.linkColor(context),
                                      ),
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
                                      tableColumnWidth:
                                          const IntrinsicColumnWidth(),
                                      tableScrollbarThumbVisibility: true,
                                      tablePadding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      p: TextStyle(
                                        fontSize: 16,
                                        height: 1.65,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                    ),
                              ),
                            )
                          : ToolActivityView(
                              storageId: '${widget.messageId}:$index',
                              title: activity.text,
                              toolName: activity.toolName,
                              status: activity.status!,
                              requestJson: activity.requestJson,
                              resultJson: activity.resultJson,
                            ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
