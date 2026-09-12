import '../../domain/ui_tool_actions.dart';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../domain/agent_models.dart';
import 'thinking_indicator.dart';
import 'chat_scroll_anchor.dart';
import 'tool_action_icon.dart';
import 'tool_payload_section.dart';
import 'user_question_history.dart';
import 'scheduled_task_history.dart';

class ToolActivityView extends StatefulWidget {
  const ToolActivityView({
    super.key,
    required this.title,
    required this.storageId,
    required this.status,
    this.toolName,
    this.requestJson,
    this.resultJson,
  });

  final String? toolName;
  final String title;
  final String storageId;
  final AgentStepStatus status;
  final String? requestJson;
  final String? resultJson;

  @override
  State<ToolActivityView> createState() => _ToolActivityViewState();
}

class _ToolActivityViewState extends State<ToolActivityView> {
  bool _expanded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _expanded =
        PageStorage.of(context).readState(
              context,
              identifier: 'tool-expanded:${widget.storageId}',
            )
            as bool? ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final running = widget.status == AgentStepStatus.running;
    final isQuestion = widget.toolName == 'askUser';
    final canExpand = !running || isQuestion;
    final showStatus = !running;
    final questionResult = isQuestion && widget.resultJson != null
        ? jsonDecode(widget.resultJson!) as Map
        : null;
    final skipped = questionResult?['skipped'] == true;
    final questionLabel = skipped
        ? '已跳过'
        : widget.status == AgentStepStatus.cancelled ||
              questionResult?['cancelled'] == true
        ? '已停止'
        : questionResult?['answer'] != null
        ? '已回答'
        : '未回答';
    final showCard = _expanded && canExpand;
    final taskOperation = scheduledTaskOperation(
      widget.toolName,
      widget.requestJson,
    );
    final taskTitle = switch (taskOperation) {
      'create' => '创建定时任务',
      'update' => '修改定时任务',
      'list' => '查询定时任务',
      'pause' => '暂停定时任务',
      'resume' => '恢复定时任务',
      'delete' => '删除定时任务',
      _ => null,
    };
    final legacyRequest =
        const {'act', 'readLocalDatabase'}.contains(widget.toolName) &&
            widget.requestJson != null
        ? jsonDecode(widget.requestJson!) as Map
        : null;
    final legacyName = widget.toolName == 'act'
        ? uiToolActions.entries
              .where((entry) => entry.value == legacyRequest?['action'])
              .map((entry) => entry.key)
              .firstOrNull
        : widget.toolName == 'readLocalDatabase'
        ? switch (legacyRequest?['action']) {
            'schema' => 'inspectLocalDatabase',
            'query' => 'queryLocalDatabase',
            _ => null,
          }
        : null;
    final title =
        taskTitle ??
        (legacyName == null ? null : toolTitle(legacyName)) ??
        (showStatus
            ? widget.title.replaceFirst(RegExp(r'^(已完成：|未完成：|已停止：)'), '')
            : widget.title);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: canExpand,
          expanded: canExpand ? _expanded : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: !canExpand
                ? null
                : () {
                    ChatScrollAnchor.beforeResize(context);
                    setState(() => _expanded = !_expanded);
                    PageStorage.of(context).writeState(
                      context,
                      _expanded,
                      identifier: 'tool-expanded:${widget.storageId}',
                    );
                  },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                children: [
                  Semantics(
                    label: switch (widget.status) {
                      AgentStepStatus.running => '正在执行',
                      AgentStepStatus.completed => '已完成',
                      AgentStepStatus.failed => '未完成',
                      AgentStepStatus.cancelled => '已停止',
                    },
                    child: ToolActionIcon(toolName: widget.toolName),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: showStatus
                        ? Text(
                            title,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          )
                        : ThinkingIndicator(label: title, animate: running),
                  ),
                  if (showStatus) ...[
                    const SizedBox(width: 8),
                    _ToolStatusBadge(
                      status: skipped
                          ? AgentStepStatus.cancelled
                          : widget.status,
                      label: isQuestion ? questionLabel : null,
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (canExpand)
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
        if (_expanded && canExpand)
          if (isQuestion)
            UserQuestionHistory(
              requestJson: widget.requestJson,
              resultJson: widget.resultJson,
              status: widget.status,
            )
          else if (taskOperation != null)
            ScheduledTaskHistory(
              operation: taskOperation,
              status: widget.status,
              requestJson: widget.requestJson,
              resultJson: widget.resultJson,
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ToolPayloadSection(
                  title: '请求参数',
                  json: widget.requestJson,
                  missing: '此记录未保存请求参数',
                ),
                const SizedBox(height: 2),
                ToolPayloadSection(
                  title: '返回结果',
                  json: widget.resultJson,
                  missing:
                      widget.requestJson != null &&
                          widget.status != AgentStepStatus.completed
                      ? '未返回结果'
                      : '此记录未保存返回结果',
                ),
                const SizedBox(height: 12),
              ],
            ),
      ],
    );
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: showCard ? 12 : 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (showCard)
            Positioned(
              left: -13,
              right: -13,
              top: -8,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: dark ? const Color(0xff222222) : Colors.white,
                  border: Border.all(
                    color: dark
                        ? const Color(0xff333333)
                        : const Color(0xffeeeeee),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: dark ? .12 : .045),
                      blurRadius: 24,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
              ),
            ),
          KeyedSubtree(key: const ValueKey('tool-content'), child: content),
        ],
      ),
    );
  }
}

class _ToolStatusBadge extends StatelessWidget {
  const _ToolStatusBadge({required this.status, this.label});
  final String? label;
  final AgentStepStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (label, icon, color) = switch (status) {
      AgentStepStatus.completed => (
        '已完成',
        Icons.check_circle_rounded,
        const Color(0xff00ad8b),
      ),
      AgentStepStatus.failed => (
        '未完成',
        Icons.error_outline_rounded,
        colors.error,
      ),
      AgentStepStatus.cancelled => (
        '已停止',
        Icons.stop_circle_outlined,
        colors.onSurfaceVariant,
      ),
      AgentStepStatus.running => (
        '执行中',
        Icons.more_horiz_rounded,
        colors.onSurfaceVariant,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              this.label ?? label,
              style: TextStyle(fontSize: 11, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
