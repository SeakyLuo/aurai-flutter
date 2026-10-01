import 'package:flutter/material.dart';
import '../../domain/agent_models.dart';
import 'chat_scroll_anchor.dart';
import 'thinking_indicator.dart';
import 'tool_action_icon.dart';
import 'tool_expand_arrow.dart';
import '../../domain/workspace_file_changes.dart';
import 'workspace_changes_view.dart';

class ToolActivityGroup extends StatefulWidget {
  const ToolActivityGroup({
    super.key,
    required this.storageId,
    required this.toolName,
    required this.statuses,
    required this.children,
    this.fileResults = const [],
    this.active = false,
    this.activeLabel,
  });
  final String storageId;
  final String toolName;
  final List<AgentStepStatus> statuses;
  final List<Widget> children;
  final List<String?> fileResults;
  final bool active;
  final String? activeLabel;
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
    final running =
        widget.active || widget.statuses.contains(AgentStepStatus.running);
    final expanded = _expanded;
    final label = widget.active
        ? widget.activeLabel!
        : '${toolTitle(widget.toolName)} · ${widget.statuses.length} 次';
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
                      singleLine: true,
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
        if (widget.fileResults.isNotEmpty)
          WorkspaceChangesView(
            changes: WorkspaceFileChanges.fromResults(widget.fileResults),
          ),
        if (expanded) ...widget.children,
      ],
    );
  }
}
