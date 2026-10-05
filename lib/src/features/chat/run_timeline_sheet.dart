import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/ui_action.dart';
import '../../domain/agent_models.dart';
import '../../storage/run_timeline_store.dart';
import 'chat_controller.dart';
import 'group_activity_sheet.dart';
import '../../domain/markdown_plain_text.dart';
import 'message_time.dart';
import 'tool_activity_view.dart';

Future<void> showRunTimelineSheet(
  BuildContext context, {
  required ChatController controller,
  required AgentMessage message,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  builder: (_) => _RunTimelineSheet(controller: controller, message: message),
);

class _RunTimelineSheet extends StatefulWidget {
  const _RunTimelineSheet({required this.controller, required this.message});
  final ChatController controller;
  final AgentMessage message;
  @override
  State<_RunTimelineSheet> createState() => _RunTimelineSheetState();
}

class _RunTimelineSheetState extends State<_RunTimelineSheet> {
  late final _store = RunTimelineStore(widget.controller.groupStore.database);
  final _entries = <int, RunTimelineEntry>{};
  Map<String, Object?>? _run;
  bool _loading = false;
  bool _refreshPending = false;
  bool _hasEarlier = false;
  int? _earliest;
  Timer? _updates;

  @override
  void initState() {
    super.initState();
    widget.controller.groupActivityChanges.addListener(_changed);
    widget.controller.addListener(_changed);
    _load();
  }

  void _changed() {
    if (_run != null && _run!['status'] != 'running') return;
    _refreshPending = true;
    _scheduleRefresh();
  }

  void _scheduleRefresh() {
    if (!_refreshPending || _loading || _updates != null) return;
    if (_run != null && _run!['status'] != 'running') return;
    _updates = Timer(const Duration(milliseconds: 350), () {
      _updates = null;
      _load();
    });
  }

  Future<void> _load({bool earlier = false}) async {
    if (_loading) return;
    _updates?.cancel();
    _updates = null;
    if (!earlier) _refreshPending = false;
    setState(() => _loading = true);
    final loaded = await runUiAction(context, () async {
      final page = await _store.read(
        widget.message.runId!,
        before: earlier ? _earliest : null,
      );
      if (!mounted) return;
      setState(() {
        _run = page.run;
        for (final entry in page.entries) {
          _entries[entry.eventId] = entry;
        }
        if (earlier || _earliest == null) {
          _hasEarlier = page.hasEarlier;
          _earliest = page.firstEventId;
        }
      });
    });
    if (!mounted) return;
    setState(() => _loading = false);
    if (!loaded && _run == null) {
      Navigator.pop(context);
      return;
    }
    _scheduleRefresh();
  }

  @override
  void dispose() {
    _updates?.cancel();
    widget.controller.groupActivityChanges.removeListener(_changed);
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final run = _run;
    final colors = Theme.of(context).colorScheme;
    final entries = _entries.values.toList()
      ..sort((a, b) {
        final time = a.createdAt.compareTo(b.createdAt);
        return time == 0 ? a.eventId.compareTo(b.eventId) : time;
      });
    final status = switch (run?['status']) {
      'completed' => '已完成',
      'failed' => '执行中断',
      'cancelled' => '已停止',
      'interrupted' => '连接中断',
      _ => '执行中',
    };
    final conversationId = run?['conversation_id'] as String?;
    final activity = conversationId == null
        ? null
        : widget.controller
              .groupActivitiesFor(conversationId)
              .where((activity) => activity.runId == widget.message.runId)
              .firstOrNull;
    return GroupRunDetailsLayout(
      controller: widget.controller,
      sender: widget.message.sender!,
      conversationId: conversationId,
      activity: activity,
      followBottom: false,
      children: [
        if (run == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          Text(
            status,
            style: TextStyle(fontSize: 15, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          if (_hasEarlier)
            TextButton(
              onPressed: _loading ? null : () => _load(earlier: true),
              child: const Text('查看更早过程'),
            ),
          if (entries.isEmpty) const Text('尚未产生过程记录'),
          for (final entry in entries) _entry(entry),
        ],
      ],
    );
  }

  Widget _entry(RunTimelineEntry entry) {
    final tool = entry.tool;
    if (tool != null) {
      return ToolActivityView(
        key: ValueKey(entry.eventId),
        storageId: 'timeline:${tool['id']}',
        title: tool['title'] as String,
        toolName: tool['name'] as String,
        status: AgentStepStatus.values.byName(tool['status'] as String),
        requestJson: tool['arguments_json'] as String?,
        resultJson: tool['result_json'] as String?,
        startedAt: DateTime.fromMicrosecondsSinceEpoch(
          tool['started_at'] as int,
        ),
        finishedAt: tool['finished_at'] == null
            ? null
            : DateTime.fromMicrosecondsSinceEpoch(tool['finished_at'] as int),
      );
    }
    final message = entry.message!;
    final kind = message['kind'];
    final output =
        kind == 'group_message' ||
        kind == 'final' ||
        kind == 'html_game' ||
        message['interactive_json'] != null;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      key: ValueKey(entry.eventId),
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${kind == 'message_failure'
                ? '执行中断'
                : output
                ? '消息产出'
                : kind == 'reasoning'
                ? '思考'
                : '过程说明'} · ${messageTime(DateTime.fromMicrosecondsSinceEpoch(message['created_at'] as int))}',
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          SelectableText(
            message['markdown'] == 1 || kind == 'commentary'
                ? markdownPlainText(message['text'] as String)
                : memberMentionsPlainText(message['text'] as String),
            style: TextStyle(
              fontSize: 15,
              height: 1.65,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
