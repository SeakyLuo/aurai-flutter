import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/workspace_file_changes.dart';
import 'chat_controller.dart';
import 'glass_surface.dart';
import 'workspace_changes_view.dart';
import 'project_workspace_label.dart';

/// A live task summary above the composer, using the same history as the card.
class WorkspaceChangesPanel extends StatefulWidget {
  const WorkspaceChangesPanel({
    super.key,
    required this.controller,
    required this.child,
  });
  final ChatController controller;
  final Widget child;

  @override
  State<WorkspaceChangesPanel> createState() => _WorkspaceChangesPanelState();
}

class _WorkspaceChangesPanelState extends State<WorkspaceChangesPanel> {
  List<String?> _results = [];
  WorkspaceFileChanges _changes = const WorkspaceFileChanges(
    [],
    complete: true,
  );

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final composer = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProjectWorkspaceLabel(controller: controller),
        widget.child,
      ],
    );
    if (!controller.isBusy) return composer;
    final results = controller.steps.map((step) => step.resultJson).toList();
    if (!listEquals(_results, results)) {
      _results = results;
      _changes = WorkspaceFileChanges.fromResults(results);
    }
    if (_changes.files.isEmpty) return composer;
    final count = _changes.lineCount;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GlassSurface(
                  radius: 16,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => WorkspaceChangesView(
                      changes: _changes,
                    ).showAll(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${_changes.complete ? '' : '至少 '}${_changes.files.length} 个文件已更改',
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (count != null)
                            WorkspaceLineCounts(
                              count,
                              partial:
                                  !_changes.allLinesCounted ||
                                  !_changes.complete,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        composer,
      ],
    );
  }
}
