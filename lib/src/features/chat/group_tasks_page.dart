import 'package:flutter/material.dart';

import '../../scheduling/task_detail_page.dart';
import '../../widgets/empty_data_view.dart';
import 'chat_controller.dart';
import 'conversation_task_navigation.dart';
import 'program_task_panel.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import '../../storage/private_task_state.dart';
import 'private_task_panel.dart';
import 'private_goal_panel.dart';

class GroupTasksPage extends StatelessWidget {
  const GroupTasksPage({
    super.key,
    required this.controller,
    required this.conversationId,
    this.originTaskId,
    this.privateStore,
  });
  final ChatController controller;
  final String conversationId;
  final String? originTaskId;
  final PrivateTaskState? privateStore;

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: SettingsAppBar(
      title: privateStore == null ? '群计划' : '计划',
      onBack: () => Navigator.pop(context),
    ),
    body: ListenableBuilder(
      listenable: controller.scheduledTasks,
      builder: (context, _) {
        final tasks = conversationTasks(
          controller,
          conversationId,
          originTaskId: originTaskId,
        );
        final padding = EdgeInsets.fromLTRB(
          16,
          settingsHeaderHeight(context) + 16,
          16,
          MediaQuery.paddingOf(context).bottom + 24,
        );
        return LayoutBuilder(
          builder: (context, constraints) => ListView(
            padding: padding,
            children: [
              if (privateStore != null)
                PrivateGoalPanel(
                  store: privateStore!,
                  controller: controller,
                  showTasks: false,
                  builder: (context, goal) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (goal != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: goal,
                        ),
                      PrivateTaskPanel(
                        store: privateStore!,
                        empty: tasks.isEmpty && goal == null
                            ? SizedBox(
                                height:
                                    constraints.maxHeight - padding.vertical,
                                child: const EmptyDataView(title: '暂无计划'),
                              )
                            : null,
                      ),
                    ],
                  ),
                )
              else
                ProgramTaskPanel(
                  controller: controller,
                  conversationId: conversationId,
                  expanded: true,
                  empty: tasks.isEmpty
                      ? SizedBox(
                          height: constraints.maxHeight - padding.vertical,
                          child: const EmptyDataView(title: '暂无群计划'),
                        )
                      : null,
                  child: const SizedBox.shrink(),
                ),
              Column(
                children: [
                  for (final task in tasks)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Material(
                        color: settingsFieldColor(context),
                        borderRadius: BorderRadius.circular(26),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          leading: const SettingsIcon(
                            type: SettingsIconType.tasks,
                          ),
                          title: Text(task['title'] as String),
                          trailing: const SettingsIcon(
                            type: SettingsIconType.chevron,
                          ),
                          onTap: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TaskDetailPage(
                                controller: controller,
                                id: task['id'] as String,
                                returnConversationId: conversationId,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}
