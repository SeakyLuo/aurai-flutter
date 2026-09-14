import 'package:flutter/material.dart';
import '../../domain/agent_models.dart';
import 'chat_scroll_anchor.dart';
import 'thinking_indicator.dart';
import 'tool_action_icon.dart';
import 'tool_expand_arrow.dart';

class ToolActivityGroup extends StatefulWidget {
  const ToolActivityGroup({
    super.key,
    required this.storageId,
    required this.toolName,
    required this.statuses,
    required this.children,
  });
  final String storageId;
  final String toolName;
  final List<AgentStepStatus> statuses;
  final List<Widget> children;
  @override
  State<ToolActivityGroup> createState() => _ToolActivityGroupState();
}

class _ToolActivityGroupState extends State<ToolActivityGroup> {
  bool _expanded = false;
  String get _storageId => 'tool-group:${widget.storageId}';
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _expanded =
        PageStorage.of(context).readState(context, identifier: _storageId)
            as bool? ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final running = widget.statuses.contains(AgentStepStatus.running);
    final failed = widget.statuses
        .where((s) => s == AgentStepStatus.failed)
        .length;
    final cancelled = widget.statuses
        .where((s) => s == AgentStepStatus.cancelled)
        .length;
    final expanded = _expanded;
    final label = [
      '${toolTitle(widget.toolName)} · ${widget.statuses.length} 次',
      if (running) '执行中',
      if (failed > 0) '$failed 项失败',
      if (cancelled > 0) '$cancelled 项已停止',
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: expanded,
          label: label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              ChatScrollAnchor.beforeResize(context);
              setState(() => _expanded = !expanded);
              PageStorage.of(
                context,
              ).writeState(context, _expanded, identifier: _storageId);
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                children: [
                  Expanded(
                    child: ThinkingIndicator(
                      label: label,
                      animate: running,
                      leading: SizedBox.square(
                        dimension: MediaQuery.textScalerOf(context).scale(18),
                        child: FittedBox(
                          child: ToolActionIcon(toolName: widget.toolName),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Transform.translate(
                    offset: const Offset(4, 0),
                    child: ToolExpandArrow(expanded: expanded),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (expanded) ...widget.children,
      ],
    );
  }
}
