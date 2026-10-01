import '../../widgets/empty_data_view.dart';
import '../../storage/private_task_state.dart';
import 'package:flutter/material.dart';

import 'glass_surface.dart';
import 'private_task_list_nodes.dart';
import 'settings_icon.dart';
import 'settings_appearance.dart';
import 'question_icon.dart';

/// Inline task progress on the existing composer glass surface.
class PrivateTaskList extends StatefulWidget {
  const PrivateTaskList({super.key, required this.steps, required this.store});
  final List<Map> steps;
  final PrivateTaskState store;

  @override
  State<PrivateTaskList> createState() => _PrivateTaskListState();
}

class _PrivateTaskListState extends State<PrivateTaskList> {
  @override
  Widget build(BuildContext context) {
    final steps = widget.steps;
    final completed = steps
        .where((step) => step['status'] == 'completed')
        .length;
    final current =
        steps.where((step) => step['status'] == 'in_progress').firstOrNull ??
        steps.where((step) => step['status'] == 'pending').firstOrNull;
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
                      label: '任务清单，已完成 $completed/${steps.length}，$summary',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _showSteps,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Text(
                                '任务 · $completed/${steps.length}',
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
                  const Expanded(
                    child: Text(
                      '任务清单',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: StreamBuilder<Map<String, dynamic>>(
                  stream: widget.store.changes,
                  initialData: {'steps': widget.steps},
                  builder: (context, snapshot) {
                    final steps =
                        (snapshot.requireData['steps'] as List? ?? const [])
                            .cast<Map>();
                    return steps.isEmpty
                        ? EmptyDataView(title: '暂无任务')
                        : PrivateTaskListNodes(steps: steps);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
