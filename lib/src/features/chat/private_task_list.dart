import '../../widgets/empty_data_view.dart';
import '../../storage/private_task_state.dart';
import 'dart:async';
import 'package:flutter/material.dart';

import 'glass_surface.dart';
import 'private_task_list_nodes.dart';
import 'settings_icon.dart';
import 'settings_appearance.dart';
import 'question_icon.dart';

/// Inline task progress on the existing composer glass surface.
class PrivateTaskList extends StatelessWidget {
  const PrivateTaskList({super.key, required this.steps, required this.store});
  final List<Map> steps;
  final PrivateTaskState store;

  @override
  Widget build(BuildContext context) =>
      TaskProgressList(steps: steps, changes: store.changes);
}

class TaskProgressList extends StatefulWidget {
  const TaskProgressList({
    super.key,
    required this.steps,
    required this.changes,
    this.title = '任务清单',
    this.label = '任务',
  });
  final List<Map> steps;
  final Stream<Map<String, dynamic>> changes;
  final String title, label;

  @override
  State<TaskProgressList> createState() => _TaskProgressListState();
}

class _TaskProgressListState extends State<TaskProgressList> {
  @override
  Widget build(BuildContext context) {
    final steps = widget.steps;
    final completed = steps
        .where(
          (step) =>
              step['status'] == 'completed' || step['status'] == 'skipped',
        )
        .length;
    if (completed == steps.length) return const SizedBox.shrink();
    var currentIndex = steps.indexWhere(
      (step) => step['status'] == 'in_progress',
    );
    if (currentIndex == -1)
      currentIndex = steps.indexWhere((step) => step['status'] == 'pending');
    final current = currentIndex == -1 ? null : steps[currentIndex];
    final position = currentIndex == -1 ? steps.length : currentIndex + 1;
    final summary = current == null ? '任务已完成' : current['step'] as String;
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: GlassSurface(
            radius: 18,
            child: IntrinsicWidth(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      button: true,
                      label:
                          '任务清单，第 $position/${steps.length} 步，已完成 $completed 步，$summary',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _showSteps,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Text(
                                '${widget.label} · $position/${steps.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  summary,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colors.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              RotatedBox(
                                quarterTurns: 3,
                                child: const SizedBox.square(
                                  dimension: 16,
                                  child: FittedBox(
                                    child: SettingsIcon(
                                      type: SettingsIconType.chevron,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showSteps() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    builder: (context) => SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  SettingsGlassAction(
                    label: '关闭',
                    icon: Icons.close_rounded,
                    iconWidget: const QuestionIcon(
                      type: QuestionIconType.close,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: StreamBuilder<Map<String, dynamic>>(
                      stream: widget.changes,
                      initialData: {'title': widget.title},
                      builder: (context, snapshot) => Text(
                        snapshot.requireData['title'] as String? ??
                            widget.title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Flexible(
              child: StreamBuilder<Map<String, dynamic>>(
                stream: widget.changes,
                initialData: {'steps': widget.steps},
                builder: (context, snapshot) {
                  final steps =
                      (snapshot.requireData['steps'] as List? ?? const [])
                          .cast<Map>();
                  return steps.isEmpty
                      ? EmptyDataView(title: '暂无任务')
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                          child: PrivateTaskListNodes(steps: steps),
                        );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
