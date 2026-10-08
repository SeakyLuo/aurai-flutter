import 'app_bottom_sheet.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../app/ui_action.dart';
import '../../domain/agent_models.dart';
import '../../domain/message_sender.dart';
import '../../domain/source_reference.dart';
import '../../platform/aurai_platform.dart';
import '../../storage/run_timeline_store.dart';
import 'chat_controller.dart';
import 'group_activity_sheet.dart';
import '../../domain/markdown_plain_text.dart';
import 'message_time.dart';
import 'tool_activity_view.dart';
import 'cjk_strong_syntax.dart';
import 'markdown_link_underlines.dart';
import 'task_elapsed.dart';
import 'settings_appearance.dart';
import 'question_icon.dart';
import 'thinking_indicator.dart';

Future<void> showRunTimelineSheet(
  BuildContext context, {
  required ChatController controller,
  required AgentMessage message,
}) => showTaskRunTimelineSheet(
  context,
  controller: controller,
  runId: message.runId!,
  sender: message.sender!,
);

Future<void> showTaskRunTimelineSheet(
  BuildContext context, {
  required ChatController controller,
  required String runId,
  required MessageSender sender,
  bool live = false,
}) => showAppBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  builder: (_) => _RunTimelineSheet(
    controller: controller,
    runId: runId,
    sender: sender,
    live: live,
  ),
);

class _RunTimelineSheet extends StatefulWidget {
  const _RunTimelineSheet({
    required this.controller,
    required this.runId,
    required this.sender,
    required this.live,
  });
  final ChatController controller;
  final String runId;
  final MessageSender sender;
  final bool live;
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
  bool _stopping = false;

  Future<void> _stop() async {
    setState(() => _stopping = true);
    try {
      await runUiAction(context, () async {
        if (widget.controller.activeConversation.activeRunId == widget.runId) {
          await widget.controller.stop();
        }
      });
    } finally {
      if (mounted) setState(() => _stopping = false);
    }
  }

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
        widget.runId,
        before: earlier ? _earliest : null,
      );
      if (!mounted) return;
      setState(() {
        _run = page.run;
        _entries.removeWhere((id, _) => page.turnEventIds.contains(id));
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
    final entries =
        _entries.values.where((entry) {
          if (entry.tool != null)
            return entry.tool!['name'] != 'sendGroupMessage';
          return {
                'commentary',
                'reasoning',
                'assistant',
              }.contains(entry.message!['kind']) &&
              entry.message!['interactive_json'] == null;
        }).toList()..sort((a, b) {
          final time = a.createdAt.compareTo(b.createdAt);
          return time == 0 ? a.eventId.compareTo(b.eventId) : time;
        });
    final status = switch (run?['status']) {
      'completed' => '本轮完成',
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
              .where((activity) => activity.runId == widget.runId)
              .firstOrNull;
    return GroupRunDetailsLayout(
      controller: widget.controller,
      sender: widget.sender,
      conversationId: conversationId,
      activity: activity,
      followBottom: widget.live,
      trailing: widget.live && run?['status'] == 'running'
          ? SettingsGlassAction(
              label: _stopping ? '终止中' : '终止思考',
              icon: Icons.stop_rounded,
              iconWidget: const QuestionIcon(type: QuestionIconType.stop),
              onPressed: _stopping ? null : _stop,
            )
          : null,
      children: [
        if (run == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          if (!widget.live) ...[
            Text(
              '$status'
              '${run['elapsed_ms'] == null ? '' : ' · ${taskDuration(Duration(milliseconds: run['elapsed_ms'] as int))}'}',
              style: TextStyle(fontSize: 15, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
          ],
          if (_hasEarlier)
            TextButton(
              onPressed: _loading ? null : () => _load(earlier: true),
              child: const Text('查看更早过程'),
            ),
          if (entries.isEmpty)
            ThinkingIndicator(
              label: run['status'] == 'running' ? '正在思考' : '本轮已结束',
              fontSize: 15,
              animate: run['status'] == 'running' && !_stopping,
            ),
          for (final entry in entries) _entry(entry),
        ],
      ],
    );
  }

  Widget _entry(RunTimelineEntry entry) {
    final tool = entry.tool;
    if (tool != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ToolActivityView(
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
        ),
      );
    }
    final message = entry.message!;
    if (widget.live) {
      return Padding(
        key: ValueKey(entry.eventId),
        padding: const EdgeInsets.only(bottom: 16),
        child: SelectableText(
          memberMentionsPlainText(message['text'] as String),
          style: TextStyle(
            fontSize: 15,
            height: 1.65,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
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
                ? '回复'
                : kind == 'reasoning'
                ? '思考'
                : '过程说明'} · ${messageTime(DateTime.fromMicrosecondsSinceEpoch(message['created_at'] as int))}',
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          if (output || kind == 'commentary' || message['markdown'] == 1)
            MarkdownLinkUnderlines(
              child: MarkdownBody(
                data: memberMentionsPlainText(message['text'] as String),
                // Preserve the AI's single newlines; Markdown otherwise joins them into spaces.
                softLineBreak: true,
                selectable: true,
                inlineSyntaxes: [CjkStrongSyntax()],
                onTapLink: (_, href, _) => _openLink(href!),
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                    .copyWith(
                      p: TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: output
                            ? colors.onSurface
                            : colors.onSurfaceVariant,
                      ),
                      tableColumnWidth: const IntrinsicColumnWidth(),
                      tableScrollbarThumbVisibility: true,
                    ),
              ),
            )
          else
            SelectableText(
              memberMentionsPlainText(message['text'] as String),
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: colors.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openLink(String href) async {
    await runUiAction(context, () async {
      final file = SourceReference.fromLocalLink(href, '本地文件');
      if (file != null) {
        await AuraiPlatform.instance.openSourceFile(file.url);
      } else {
        final uri = Uri.parse(href);
        if (!{'http', 'https'}.contains(uri.scheme))
          throw StateError('无法打开此链接');
        await AuraiPlatform.instance.startIntent({
          'action': 'android.intent.action.VIEW',
          'data': href,
        });
      }
    });
  }
}
