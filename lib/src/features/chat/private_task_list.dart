import 'app_bottom_sheet.dart';
import 'app_sheet_body.dart';
import '../../widgets/empty_data_view.dart';
import '../../storage/private_task_state.dart';
import 'dart:async';
import 'package:flutter/material.dart';

import '../../app/global_ui.dart';
import 'glass_surface.dart';
import 'private_task_list_nodes.dart';
import 'settings_icon.dart';
import 'settings_appearance.dart';
import 'question_icon.dart';
import 'task_completion_transition.dart';

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
    this.title = '执行计划',
    this.label = '计划',
  });
  final List<Map> steps;
  final Stream<Map<String, dynamic>> changes;
  final String title, label;

  @override
  State<TaskProgressList> createState() => _TaskProgressListState();
}

class _TaskProgressListState extends State<TaskProgressList> {
  final _iconLink = LayerLink();
  static const _iconSize = 28.0;
  @override
  Widget build(BuildContext context) {
    final steps = widget.steps;
    final completed = steps
        .where(
          (step) =>
              step['status'] == 'completed' || step['status'] == 'skipped',
        )
        .length;
    if (steps.isEmpty) return const SizedBox.shrink();
    var currentIndex = steps.indexWhere(
      (step) => step['status'] == 'in_progress',
    );
    if (currentIndex == -1)
      currentIndex = steps.indexWhere((step) => step['status'] == 'pending');
    final current = currentIndex == -1 ? null : steps[currentIndex];
    final position = currentIndex == -1 ? steps.length : currentIndex + 1;
    final summary = current == null ? '计划已完成' : current['step'] as String;
    final colors = Theme.of(context).colorScheme;
    final accent = GlobalUI.highlightTextColor(context);
    final count = '$completed/' + steps.length.toString();
    return TaskCompletionTransition(
      iconLink: _iconLink,
      iconSize: _iconSize,
      completed: completed == steps.length,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: GlassSurface(
          radius: 22,
          shadowOpacity: .65,
          child: Material(
            color: Colors.transparent,
            child: Semantics(
              button: true,
              label: widget.title + '，已完成 $count 步，第 $position 步，$summary',
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: _showSteps,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                  child: Row(
                    children: [
                      CompositedTransformTarget(
                        link: _iconLink,
                        child: SizedBox.square(
                          dimension: _iconSize,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              TweenAnimationBuilder<double>(
                                tween: Tween(end: completed / steps.length),
                                duration:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : const Duration(milliseconds: 250),
                                builder: (context, value, _) => SizedBox.expand(
                                  child: CircularProgressIndicator(
                                    value: value,
                                    strokeWidth: 1.65,
                                    strokeCap: StrokeCap.round,
                                    color: accent,
                                    backgroundColor: colors.outlineVariant
                                        .withValues(alpha: .5),
                                  ),
                                ),
                              ),
                              SizedBox.square(
                                dimension: 18,
                                child: FittedBox(
                                  child: SettingsIcon(
                                    type: SettingsIconType.taskList,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.3,
                                fontWeight: FontWeight.w500,
                                color: accent,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              summary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: colors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          count,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            color: colors.onSurfaceVariant,
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
      ),
    );
  }

  Future<void> _showSteps() => showAppBottomSheet<void>(
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
        child: AppSheetBody(
          shrinkWrap: true,
          header: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                SettingsGlassAction(
                  label: '关闭',
                  icon: Icons.close_rounded,
                  iconWidget: const QuestionIcon(type: QuestionIconType.close),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: StreamBuilder<Map<String, dynamic>>(
                    stream: widget.changes,
                    initialData: {'title': widget.title},
                    builder: (context, snapshot) => Text(
                      snapshot.requireData['title'] as String? ?? widget.title,
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
          child: StreamBuilder<Map<String, dynamic>>(
            stream: widget.changes,
            initialData: {'steps': widget.steps},
            builder: (context, snapshot) {
              final steps = (snapshot.requireData['steps'] as List? ?? const [])
                  .cast<Map>();
              return steps.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.fromLTRB(16, 76, 16, 24),
                      child: EmptyDataView(title: '暂无计划'),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 76, 16, 16),
                      child: PrivateTaskListNodes(steps: steps),
                    );
            },
          ),
        ),
      ),
    ),
  );
}
