import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../../app/ui_action.dart';
import '../../app/glass_notice.dart';
import '../../domain/agent_models.dart';
import '../../domain/source_reference.dart';
import '../../platform/aurai_platform.dart';
import 'chat_controller.dart';
import 'settings_appearance.dart';
import 'tool_activity_view.dart';

class SubagentDetailPage extends StatefulWidget {
  const SubagentDetailPage({
    super.key,
    required this.controller,
    required this.runId,
  });
  final ChatController controller;
  final String runId;
  @override
  State<SubagentDetailPage> createState() => _SubagentDetailPageState();
}

class _SubagentDetailPageState extends State<SubagentDetailPage> {
  Map<String, Object?>? _run;
  Map _delegation = {}, _result = {};
  List<Map<String, Object?>> _tools = [];
  bool _loading = true, _failed = false, _reading = false, _dirty = false;
  StreamSubscription<String>? _changes;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _changes = widget.controller.subagentRuns.changes
        .where((id) => id == widget.runId)
        .listen((_) => _load());
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _changes?.cancel();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    if (_reading) {
      _dirty = true;
      return;
    }
    _reading = true;
    _dirty = false;
    final ok = await runUiAction(context, () async {
      final store = widget.controller.subagentRuns;
      final run = await store.read(widget.runId);
      final records = await Future.wait([
        store.tools(widget.runId),
        store.database.query(
          'tool_calls',
          where: 'id = ?',
          whereArgs: [run['parent_tool_call_id']],
          limit: 1,
        ),
      ]);
      final resultJson = records[1].single['result_json'] as String?;
      if (!mounted) return;
      setState(() {
        _run = run;
        _delegation =
            (jsonDecode(run['configuration_json'] as String)
                    as Map)['delegation']
                as Map;
        _tools = records[0];
        _result = resultJson == null ? {} : jsonDecode(resultJson) as Map;
        _loading = false;
        _failed = false;
      });
    });
    _reading = false;
    if (!mounted) return;
    if (!ok)
      setState(() {
        _failed = true;
        _loading = false;
      });
    if (_dirty) unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.controller.pendingQuestion;
    final waiting = question?.executionRunId == widget.runId;
    final status = waiting
        ? '等你回复'
        : switch (_run?['status']) {
            'running' => '执行中',
            'completed' => '已完成',
            'cancelled' => '已停止',
            'interrupted' => '已中断',
            _ => '未完成',
          };
    final error = _result['error'] as String?;
    final answer = _result['answer'] as String?;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        title: _delegation['title'] as String? ?? '子代理',
        onBack: () => Navigator.pop(context),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
          ? Center(
              child: TextButton(onPressed: _load, child: const Text('重试')),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                settingsHeaderHeight(context) + 16,
                20,
                MediaQuery.paddingOf(context).bottom + 24,
              ),
              children: [
                if (waiting)
                  TextButton(
                    onPressed: () {
                      final detailRoute = ModalRoute.of(context);
                      Navigator.popUntil(
                        context,
                        (route) => route != detailRoute && route is PageRoute,
                      );
                    },
                    child: const Text('返回聊天回复'),
                  ),
                Text(
                  status,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _delegation['task'] as String,
                  style: const TextStyle(fontSize: 16, height: 1.6),
                ),
                if (error != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => ScaffoldMessenger.of(context).showToast(
                        SnackBar(content: Text(error)),
                        kind: ToastKind.error,
                      ),
                      child: const Text('查看原因'),
                    ),
                  ),
                if (answer != null && answer.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text(
                    '结果',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  MarkdownBody(
                    data: answer,
                    selectable: true,
                    onTapLink: (_, href, _) {
                      runUiAction(context, () async {
                        final file = SourceReference.fromLocalLink(
                          href!,
                          '本地文件',
                        );
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
                    },
                  ),
                ],
                if (_tools.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text(
                    '执行过程',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  for (final tool in _tools)
                    ToolActivityView(
                      storageId: tool['id'] as String,
                      title: tool['title'] as String,
                      toolName: tool['name'] as String,
                      callId: tool['provider_call_id'] as String,
                      requestJson: tool['arguments_json'] as String,
                      resultJson: tool['result_json'] as String?,
                      status: switch (tool['status']) {
                        'running' => AgentStepStatus.running,
                        'completed' => AgentStepStatus.completed,
                        'cancelled' => AgentStepStatus.cancelled,
                        _ => AgentStepStatus.failed,
                      },
                    ),
                ],
                if ((_delegation['context'] as String).isNotEmpty) ...[
                  const SizedBox(height: 20),
                  ExpansionTile(
                    title: const Text('参考资料'),
                    tilePadding: EdgeInsets.zero,
                    children: [
                      SelectableText(_delegation['context'] as String),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}
