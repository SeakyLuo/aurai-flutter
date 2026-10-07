import 'package:flutter/material.dart';
import '../../app/ui_action.dart';
import '../../domain/message_sender.dart';
import '../../widgets/empty_data_view.dart';
import 'chat_controller.dart';
import 'message_time.dart';
import 'run_timeline_sheet.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'task_elapsed.dart';

String taskRunStatus(String status) => switch (status) {
  'running' => '执行中',
  'completed' => '本轮完成',
  'failed' => '执行中断',
  'cancelled' => '已停止',
  'interrupted' => '连接中断',
  _ => '等待执行',
};

class TaskExecutionRecordsPage extends StatefulWidget {
  const TaskExecutionRecordsPage({
    super.key,
    required this.controller,
    required this.conversationId,
    required this.sender,
  });
  final ChatController controller;
  final String conversationId;
  final MessageSender sender;
  @override
  State<TaskExecutionRecordsPage> createState() =>
      _TaskExecutionRecordsPageState();
}

class _TaskExecutionRecordsPageState extends State<TaskExecutionRecordsPage> {
  final _runs = <Map<String, Object?>>[];
  bool _loading = false, _failed = false, _more = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final succeeded = await runUiAction(context, () async {
      final db = widget.controller.groupStore.database;
      final rows = await db.query(
        'agent_runs',
        columns: ['id', 'status', 'started_at', 'elapsed_ms'],
        where: 'conversation_id = ? AND parent_run_id IS NULL',
        whereArgs: [widget.conversationId],
        orderBy: 'started_at DESC, id DESC',
        limit: 40,
        offset: _runs.length,
      );
      if (!mounted) return;
      setState(() {
        _runs.addAll(rows);
        _more = rows.length == 40;
      });
    });
    if (mounted)
      setState(() {
        _loading = false;
        _failed = !succeeded;
      });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: SettingsAppBar(title: '执行过程', onBack: () => Navigator.pop(context)),
    body: ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        settingsHeaderHeight(context) + 16,
        16,
        MediaQuery.paddingOf(context).bottom + 24,
      ),
      children: [
        if (_runs.isEmpty && !_loading && !_failed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 80),
            child: EmptyDataView(title: '尚未执行'),
          ),
        for (final run in _runs) _card(run),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_failed || _more)
          TextButton(onPressed: _load, child: Text(_failed ? '重试' : '查看更早记录')),
      ],
    ),
  );

  Widget _card(Map<String, Object?> run) {
    final time = messageTime(
      DateTime.fromMicrosecondsSinceEpoch(run['started_at'] as int),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: settingsFieldColor(context),
        borderRadius: BorderRadius.circular(26),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            ListTile(
              title: Text(time),
              subtitle: Text(
                '${taskRunStatus(run['status'] as String)}'
                '${run['elapsed_ms'] == null ? '' : ' · ${taskDuration(Duration(milliseconds: run['elapsed_ms'] as int))}'}',
              ),
              trailing: const SettingsIcon(type: SettingsIconType.chevron),
              onTap: () => showTaskRunTimelineSheet(
                context,
                controller: widget.controller,
                runId: run['id'] as String,
                sender: widget.sender,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
