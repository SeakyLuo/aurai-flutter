import 'tool_inline_detail.dart';
import 'tool_expand_arrow.dart';
import 'question_icon.dart';
import '../../domain/source_reference.dart';
import 'source_icon.dart';
import 'web_page_tool_details.dart';
import '../../skills/skill_icon.dart';
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

  bool get _failedQuestion =>
      widget.toolName == 'askUser' && widget.status == AgentStepStatus.failed;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _expanded =
        PageStorage.of(context).readState(
              context,
              identifier: 'tool-expanded:${widget.storageId}',
            )
            as bool? ??
        _failedQuestion;
  }

  @override
  void didUpdateWidget(ToolActivityView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != AgentStepStatus.failed && _failedQuestion) {
      _expanded = true;
      PageStorage.of(context).writeState(
        context,
        true,
        identifier: 'tool-expanded:${widget.storageId}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final skillIcon =
        widget.toolName == 'runSkill' && widget.requestJson != null
        ? (jsonDecode(widget.requestJson!) as Map)['icon'] as String? ?? 'skill'
        : null;
    final pageResult =
        widget.toolName == 'readWebPage' &&
            widget.status == AgentStepStatus.completed &&
            widget.resultJson != null
        ? jsonDecode(widget.resultJson!) as Map
        : null;
    final pageUrl = pageResult?['url'] as String?;
    final pageSource = pageUrl == null
        ? null
        : SourceReference(
            url: pageUrl,
            title: pageResult!['title'] as String? ?? '',
            siteName: pageResult['siteName'] as String?,
          );
    final running = widget.status == AgentStepStatus.running;
    final waitingForUser =
        running &&
        widget.resultJson != null &&
        ((jsonDecode(widget.resultJson!) as Map)['userAction']
                as Map?)?['pending'] ==
            true;
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
        const {
              'act',
              'readLocalDatabase',
              'manageSkill',
            }.contains(widget.toolName) &&
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
        : widget.toolName == 'manageSkill'
        ? switch (legacyRequest?['action']) {
            'list' => 'listSkills',
            'read' => 'readSkill',
            'save' =>
              legacyRequest?['previousName'] == null
                  ? 'createSkill'
                  : 'updateSkill',
            'delete' => 'deleteSkill',
            _ => null,
          }
        : null;
    final title =
        (widget.toolName == 'readWebPage' ? '读取网页' : null) ??
        taskTitle ??
        (legacyName == null ? null : toolTitle(legacyName)) ??
        (showStatus
            ? widget.title.replaceFirst(RegExp(r'^(已完成：|未完成：|已停止：)'), '')
            : widget.title);
    final inlineDetail = toolInlineDetail(
      legacyName ?? widget.toolName,
      widget.requestJson,
      widget.resultJson,
    );
    final displayTitle = isQuestion && inlineDetail != null
        ? '$title · $inlineDetail'
        : title;
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
                  Expanded(
                    child: ThinkingIndicator(
                      leading: Semantics(
                        label: waitingForUser
                            ? '等待你操作'
                            : switch (widget.status) {
                                AgentStepStatus.running => '正在执行',
                                AgentStepStatus.completed => '已完成',
                                AgentStepStatus.failed => '未完成',
                                AgentStepStatus.cancelled => '已停止',
                              },
                        child: SizedBox.square(
                          dimension: MediaQuery.textScalerOf(context).scale(18),
                          child: FittedBox(
                            child: waitingForUser
                                ? const QuestionIcon(
                                    type: QuestionIconType.userAction,
                                  )
                                : pageSource != null
                                ? SourceIcon(source: pageSource, size: 18)
                                : skillIcon == null
                                ? ToolActionIcon(toolName: widget.toolName)
                                : SkillIcon(skillIcon),
                          ),
                        ),
                      ),
                      label: waitingForUser ? '等待你操作' : displayTitle,
                      animate: running && !waitingForUser,
                      singleLine: true,
                      detail: isQuestion || waitingForUser
                          ? null
                          : inlineDetail,
                    ),
                  ),
                  if (showStatus &&
                      (widget.status != AgentStepStatus.completed ||
                          skipped)) ...[
                    const SizedBox(width: 8),
                    Transform.translate(
                      offset: const Offset(4, 0),
                      child: _ToolStatusBadge(
                        status: skipped
                            ? AgentStepStatus.cancelled
                            : widget.status,
                        label: isQuestion ? questionLabel : null,
                        showIcon: !skipped,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (canExpand)
                    Transform.translate(
                      offset: const Offset(4, 0),
                      child: ToolExpandArrow(expanded: _expanded),
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
                if (pageSource != null) WebPageToolDetails(source: pageSource),
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
  const _ToolStatusBadge({
    required this.status,
    this.label,
    this.showIcon = true,
  });
  final bool showIcon;
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
            if (showIcon) ...[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
            ],
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
