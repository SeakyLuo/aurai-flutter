import 'package:flutter/material.dart';
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

  String get _duration {
    final duration = Duration(milliseconds: widget.summary.elapsedMilliseconds);
    if (duration.inSeconds == 0) return widget.summary.stopped ? '0秒' : '不足1秒';
    return [
      if (duration.inHours > 0) '${duration.inHours}小时',
      if (duration.inMinutes.remainder(60) > 0)
        '${duration.inMinutes.remainder(60)}分钟',
      if (duration.inSeconds.remainder(60) > 0)
        '${duration.inSeconds.remainder(60)}秒',
    ].join(' ');
  }

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
                            ? '你在 $_duration 后停止了'
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
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: activity.status == null
                          ? MediaQuery.removePadding(
                              context: context,
                              removeBottom: true,
                              child: MarkdownBody(
                                data: activity.text,
                                selectable: true,
                                onTapLink: (text, href, title) =>
                                    widget.onOpenLink(href),
                                styleSheet:
                                    MarkdownStyleSheet.fromTheme(
                                      Theme.of(context),
                                    ).copyWith(
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
