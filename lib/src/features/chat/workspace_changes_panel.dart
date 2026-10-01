import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:flutter/material.dart';

import '../../domain/workspace_file_changes.dart';
import 'chat_controller.dart';
import 'glass_surface.dart';
import 'workspace_changes_view.dart';
import 'project_git_changes_page.dart';

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
    final composer = widget.child;
    if (!controller.isBusy) return composer;
    final projects = controller.liveProjectChanges;
    final results = controller.steps.map((step) => step.resultJson).toList();
    if (!listEquals(_results, results)) {
      _results = results;
      _changes = WorkspaceFileChanges.fromResults(results);
    }
    if (_changes.files.isEmpty && projects.isEmpty) return composer;
    final projectRoots = projects
        .map((item) => 'aurai://project/${item.workspaceId}')
        .toSet();
    final otherResults = results.where(
      (json) =>
          json == null ||
          !projectRoots.contains((jsonDecode(json) as Map)['workspaceRoot']),
    );
    final other = WorkspaceFileChanges.fromResults(otherResults);
    final count = other.lineCount;
    final files =
        other.files.length +
        projects.fold<int>(0, (sum, item) => sum + item.fileCount);
    final added =
        (count?.added ?? 0) +
        projects.fold<int>(0, (sum, item) => sum + item.added);
    final removed =
        (count?.removed ?? 0) +
        projects.fold<int>(0, (sum, item) => sum + item.removed);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GlassSurface(
                  radius: 16,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => projects.isEmpty
                        ? WorkspaceChangesView(changes: other).showAll(context)
                        : Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProjectGitChangesPage.task(
                                projectId: projects.first.workspaceId,
                                taskId: projects.first.taskId,
                                initialData: projects.first.data,
                                additionalTasks: projects.length > 1
                                    ? projects
                                    : const [],
                              ),
                            ),
                          ),
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
                            '${other.complete ? '' : '至少 '}$files 个文件已更改',
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (count != null || projects.isNotEmpty)
                            WorkspaceLineCounts(
                              (added: added, removed: removed),
                              partial:
                                  !other.allLinesCounted || !other.complete,
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
