import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/ui_action.dart';
import '../../domain/message_sender.dart';
import '../../scheduling/task_detail_page.dart';
import '../../storage/conversation_rows.dart';
import '../../storage/private_task_state.dart';
import 'chat_controller.dart';
import 'home_navigation.dart';
import 'message_time.dart';
import 'settings_icon.dart';
import 'task_elapsed.dart';
import 'task_execution_records_page.dart';

class TaskDetailOverview extends StatefulWidget {
  const TaskDetailOverview({
    super.key,
    required this.controller,
    required this.conversation,
    required this.sender,
    this.originTaskId,
  });
  final ChatController controller;
  final Conversation conversation;
  final MessageSender sender;
  final String? originTaskId;
  @override
  State<TaskDetailOverview> createState() => _TaskDetailOverviewState();
}

class _TaskDetailOverviewState extends State<TaskDetailOverview> {
  Map<String, Object?>? _origin, _latest;
  Conversation? _source;
  Map<String, dynamic> _goal = {};
  bool _loaded = false, _failed = false;
  int _elapsed = 0;
  int _revision = 0;
  Timer? _update;
  late (ChatRunState, String?) _executionState;
  StreamSubscription<Map<String, dynamic>>? _goalChanges;
  late final _store = PrivateTaskState(
    widget.controller.groupStore.database,
    widget.conversation.id,
    widget.sender.id,
  );

  @override
  void initState() {
    super.initState();
    _executionState = (
      widget.conversation.runState,
      widget.conversation.activeRunId,
    );
    widget.controller.addListener(_executionChanged);
    _goalChanges = _store.changes.listen((state) {
      ++_revision;
      if (mounted) setState(() => _goal = state);
    });
    _load();
  }

  void _executionChanged() {
    final active = widget.controller.activeConversation;
    if (active.id != widget.conversation.id) return;
    final state = (active.runState, active.activeRunId);
    if (state == _executionState) return;
    _executionState = state;
    _update?.cancel();
    _update = Timer(const Duration(milliseconds: 250), _load);
  }

  Future<void> _load() async {
    final revision = _revision;
    final db = widget.controller.groupStore.database;
    final id = widget.conversation.id;
    final succeeded = await runUiAction(context, () async {
      final results = await Future.wait<Object>([
        db.query(
          'organized_tasks',
          where: 'task_id = ?',
          whereArgs: [id],
          limit: 1,
        ),
        db.query(
          'agent_runs',
          columns: ['id', 'status'],
          where: 'conversation_id = ? AND parent_run_id IS NULL',
          whereArgs: [id],
          orderBy: 'started_at DESC, id DESC',
          limit: 1,
        ),
        db.rawQuery(
          'SELECT SUM(elapsed_ms) AS elapsed FROM agent_runs WHERE conversation_id = ? AND parent_run_id IS NULL',
          [id],
        ),
        _store.read(),
      ]);
      final origins = results[0] as List<Map<String, Object?>>;
      final latest = results[1] as List<Map<String, Object?>>;
      final origin = origins.firstOrNull;
      final sourceRows = origin == null
          ? <Map<String, Object?>>[]
          : await db.query(
              'conversations',
              where: 'id = ?',
              whereArgs: [origin['conversation_id']],
              limit: 1,
            );
      if (!mounted) return;
      setState(() {
        _origin = origin;
        _source = sourceRows.isEmpty
            ? null
            : conversationFromRow(sourceRows.single);
        _latest = latest.firstOrNull;
        _elapsed =
            (results[2] as List<Map<String, Object?>>).single['elapsed']
                as int? ??
            0;
        if (revision == _revision) _goal = results[3] as Map<String, dynamic>;
        _loaded = true;
      });
    });
    if (mounted) setState(() => _failed = !succeeded);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_executionChanged);
    _update?.cancel();
    _goalChanges?.cancel();
    super.dispose();
  }

  Future<void> _openSource() => runUiAction(
    context,
    () => openHomeConversation(
      context,
      widget.controller,
      _source!.id,
      messageId: _origin!['source_message_id'] as String?,
      resetStack: true,
    ),
  ).then((_) {});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.controller,
      widget.controller.scheduledTasks,
    ]),
    builder: (context, _) {
      if (_failed) return TextButton(onPressed: _load, child: const Text('重试'));
      if (!_loaded)
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        );
      final controller = widget.controller;
      final active = controller.activeConversation;
      final current = active.id == widget.conversation.id
          ? active
          : widget.conversation;
      final running =
          current.runState == ChatRunState.running ||
          current.runState == ChatRunState.stopping;
      final scheduled = controller.scheduledTasks.tasks
          .where(
            (task) =>
                task['id'] == widget.originTaskId ||
                task['conversationId'] == widget.conversation.id,
          )
          .firstOrNull;
      final status = running
          ? (current.runState == ChatRunState.stopping ? '正在停止' : '执行中')
          : _goal['status'] == 'complete'
          ? '目标已完成'
          : _goal['status'] == 'paused'
          ? '目标已暂停'
          : _goal['status'] == 'blocked'
          ? '等待处理'
          : _goal['status'] == 'budget_limited'
          ? '目标预算已用完'
          : _latest == null
          ? '尚未执行'
          : taskRunStatus(_latest!['status'] as String);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: const Text('发起位置'),
            subtitle: Text(
              _source?.title ?? (scheduled?['title'] as String? ?? '直接创建'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: _source != null || scheduled != null
                ? const SettingsIcon(type: SettingsIconType.chevron)
                : null,
            onTap: _source != null
                ? _openSource
                : scheduled == null
                ? null
                : () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TaskDetailPage(
                        controller: controller,
                        id: scheduled['id'] as String,
                        returnConversationId: widget.conversation.id,
                      ),
                    ),
                  ),
          ),
          ListTile(
            title: Text(status),
            subtitle: Text(
              '创建于 ${messageTime(widget.conversation.createdAt)}\n'
              '已记录用时 ${taskDuration(Duration(milliseconds: _elapsed))}'
              '${_goal['objective'] == null ? '' : '\n当前目标 Token：${_goal['tokensUsed'] ?? 0}${_goal['usageIncomplete'] == true ? '（统计不完整）' : ''}'}',
            ),
            isThreeLine: true,
          ),
          ListTile(
            title: const Text('执行过程'),
            trailing: const SettingsIcon(type: SettingsIconType.chevron),
            onTap: () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => TaskExecutionRecordsPage(
                    controller: controller,
                    conversationId: widget.conversation.id,
                    sender: widget.sender,
                  ),
                ),
              );
              if (mounted) await _load();
            },
          ),
          if (running && active.id == current.id)
            ListTile(
              title: const Text('停止执行'),
              onTap: current.runState == ChatRunState.stopping
                  ? null
                  : () async {
                      await runUiAction(context, controller.stop);
                      if (mounted) await _load();
                    },
            ),
        ],
      );
    },
  );
}
