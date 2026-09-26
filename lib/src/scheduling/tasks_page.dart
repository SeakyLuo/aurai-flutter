import '../app/glass_notice.dart';
import '../domain/error_message.dart';
import 'package:flutter/material.dart';

import '../app/global_ui.dart';

import '../features/chat/chat_controller.dart';
import '../features/chat/settings_appearance.dart';
import '../features/chat/settings_icon.dart';
import 'task_filter_menu.dart';
import '../features/chat/glass_surface.dart';
import '../features/chat/message_composer.dart';
import '../features/chat/keyboard_inset.dart';
import 'scheduled_tasks.dart';
import 'task_detail_page.dart';
import 'task_action_menu.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key, required this.controller});
  final ChatController controller;
  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> with WidgetsBindingObserver {
  final _text = TextEditingController();
  final _focus = FocusNode();
  final _filterButton = GlobalKey();
  String _filter = 'all';
  bool _loading = true;
  ScheduledTasks get tasks => widget.controller.scheduledTasks;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    try {
      await tasks.reload();
    } on Object catch (error) {
      if (mounted) _notice('无法读取任务，请稍后重试：${errorMessage(error)}');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _notice(String text) => ScaffoldMessenger.of(
    context,
  ).showGlassSnackBar(SnackBar(content: Text(text)));
  Future<void> _permission() async {
    try {
      await tasks.permission();
    } on Object catch (error) {
      if (mounted) _notice('无法打开设置：${errorMessage(error)}');
    }
  }

  Future<void> _filterTasks() async {
    final button =
        _filterButton.currentContext!.findRenderObject()! as RenderBox;
    final result = await showTaskFilterMenu(
      context,
      anchor:
          button.localToGlobal(Offset(0, button.size.height)) &
          Size(button.size.width, 0),
      selected: _filter,
    );
    if (result != null && mounted) setState(() => _filter = result);
  }

  Future<void> _taskMenu(Map<String, Object?> task, Offset position) async {
    final action = await showTaskActionMenu(context, position, task);
    if (!mounted || action == null) return;
    if (action == 'edit') {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => TaskDetailPage(
            controller: widget.controller,
            id: task['id'] as String,
          ),
        ),
      );
    } else if (action == 'conversation') {
      await openTaskConversation(context, widget.controller, task);
    } else {
      await manageTask(context, tasks, task['id'] as String, action);
    }
  }

  bool _matches(Map<String, Object?> task) => switch (_filter) {
    'active' => ['scheduled', 'starting', 'running'].contains(task['state']),
    'paused' => task['state'] == 'paused',
    'history' => ![
      'scheduled',
      'starting',
      'running',
      'paused',
    ].contains(task['state']),
    _ => true,
  };
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: tasks,
    builder: (context, _) {
      final colors = Theme.of(context).colorScheme;
      final filtered = tasks.tasks.where(_matches).toList();
      return Scaffold(
        extendBodyBehindAppBar: true,
        extendBody: true,
        resizeToAvoidBottomInset: false,
        bottomNavigationBar: KeyboardInset(
          child: MessageComposer(
            controller: _text,
            focusNode: _focus,
            enabled: tasks.supported,
            hintText: '创建任务',
            maxLength: 4000,
            onChanged: (_) => setState(() {}),
            action: RoundAction(
              label: '创建任务',
              icon: Icons.arrow_upward_rounded,
              compact: true,
              primary: true,
              onPressed: !tasks.supported || _text.text.trim().isEmpty
                  ? null
                  : () {
                      if (widget.controller.needsConfiguration) {
                        _notice('请先在设置中配置模型，再创建任务');
                        return;
                      }
                      Navigator.pop(
                        context,
                        '请创建定时任务：${_text.text.trim()}。请使用定时任务工具保存，时间不明确时先询问我。',
                      );
                    },
            ),
          ),
        ),
        appBar: SettingsAppBar(
          title: '任务',
          onBack: () => Navigator.pop(context),
          actions: [
            SettingsGlassAction(
              key: _filterButton,
              label: '筛选任务',
              icon: Icons.filter_list,
              iconWidget: const SettingsIcon(type: SettingsIconType.filter),
              onPressed: _filterTasks,
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                children: [
                  if (!tasks.allowed && tasks.supported)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        MediaQuery.paddingOf(context).top + 76,
                        16,
                        8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '开启准时执行权限，让任务按计划启动',
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _permission,
                            child: const Text('去开启'),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : filtered.isEmpty
                        ? Center(
                            child: Text(
                              _filter == 'all'
                                  ? '还没有任务，在下方说说要做什么和执行时间'
                                  : '没有符合条件的任务',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              (!tasks.allowed && tasks.supported)
                                  ? 12
                                  : MediaQuery.paddingOf(context).top + 76 + 12,
                              16,
                              MediaQuery.paddingOf(context).bottom + 20,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final task = filtered[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 18),
                                child: GestureDetector(
                                  onLongPressStart: (details) =>
                                      _taskMenu(task, details.globalPosition),
                                  child: Material(
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color(0xff252525)
                                        : Colors.white,
                                    elevation: 7,
                                    shadowColor: const Color(0x14000000),
                                    surfaceTintColor: Colors.transparent,
                                    borderRadius: BorderRadius.circular(28),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: () async {
                                        final request =
                                            await Navigator.push<String>(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => TaskDetailPage(
                                                  controller: widget.controller,
                                                  id: task['id'] as String,
                                                ),
                                              ),
                                            );
                                        if (request != null && context.mounted)
                                          Navigator.pop(context, request);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Text(
                                              task['scheduleLabel'] as String,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: GlobalUI.taskTimeColor(
                                                  context,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              task['title'] as String,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              task['prompt'] as String,
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 15,
                                                height: 1.6,
                                                color: colors.onSurfaceVariant,
                                              ),
                                            ),
                                            const SizedBox(height: 18),
                                            Divider(
                                              height: 1,
                                              color: colors.outlineVariant
                                                  .withValues(alpha: .5),
                                            ),
                                            const SizedBox(height: 14),
                                            Text(
                                              task['state'] == 'scheduled'
                                                  ? '下次 ${taskTime(task['runAt'] as int)}'
                                                  : taskState(
                                                      task['state'] as String,
                                                    ),
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: colors.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

Future<void> openScheduledTasks(
  BuildContext context,
  ChatController controller,
) async {
  final request = await Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => TasksPage(controller: controller)),
  );
  if (!context.mounted || request == null) return;
  try {
    if (controller.needsConfiguration) throw StateError('请先在设置中配置模型，再创建任务');
    await controller.createConversation();
    await controller.submitGoal(request);
  } on Object catch (error) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showGlassSnackBar(
        SnackBar(
          content: Text(
            error is StateError
                ? error.message
                : '无法创建任务，请在聊天中重试：${errorMessage(error)}',
          ),
        ),
      );
  }
}
