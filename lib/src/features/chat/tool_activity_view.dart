import 'dart:convert';

import 'package:flutter/material.dart';

import '../../domain/agent_models.dart';
import 'thinking_indicator.dart';
import 'chat_scroll_anchor.dart';

class ToolActivityView extends StatefulWidget {
  const ToolActivityView({
    super.key,
    required this.title,
    required this.storageId,
    required this.status,
    this.requestJson,
    this.resultJson,
  });

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: !running,
          expanded: running ? null : _expanded,
          child: InkWell(
            onTap: running
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
                  Icon(
                    switch (widget.status) {
                      AgentStepStatus.running => Icons.more_horiz_rounded,
                      AgentStepStatus.completed => Icons.check_rounded,
                      AgentStepStatus.failed => Icons.error_outline_rounded,
                      AgentStepStatus.cancelled => Icons.stop_circle_outlined,
                    },
                    semanticLabel: switch (widget.status) {
                      AgentStepStatus.running => '正在执行',
                      AgentStepStatus.completed => '已完成',
                      AgentStepStatus.failed => '未完成',
                      AgentStepStatus.cancelled => '已停止',
                    },
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ThinkingIndicator(
                      label: widget.title,
                      animate: running,
                    ),
                  ),
                  if (!running)
                    AnimatedRotation(
                      turns: _expanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 180),
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
        if (_expanded && !running) ...[
          _PayloadSection(
            title: '请求参数',
            json: widget.requestJson,
            missing: '此记录未保存请求参数',
          ),
          _PayloadSection(
            title: '返回结果',
            json: widget.resultJson,
            missing:
                widget.requestJson != null &&
                    widget.status != AgentStepStatus.completed
                ? '未返回结果'
                : '此记录未保存返回结果',
          ),
        ],
      ],
    );
  }
}

class _PayloadSection extends StatelessWidget {
  const _PayloadSection({
    required this.title,
    required this.json,
    required this.missing,
  });
  final String title;
  final String? json;
  final String missing;

  @override
  Widget build(BuildContext context) {
    final value = json == null ? null : jsonDecode(json!);
    final text = value is Map && value['contentRetention'] == 'task_only'
        ? '此结果仅在执行时使用，未保留内容'
        : json == null
        ? missing
        : const JsonEncoder.withIndent('  ').convert(value);
    return Padding(
      padding: const EdgeInsets.only(left: 26, top: 8, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: Scrollbar(
              child: SingleChildScrollView(
                primary: false,
                child: SelectableText(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    fontFamily: 'monospace',
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
