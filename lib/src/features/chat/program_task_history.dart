import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../app/ui_action.dart';
import '../../html_games/miniapp_program_store.dart';
import 'chat_controller.dart';
import 'private_task_list_nodes.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

/// Reads public snapshots only; private program state never enters this list.
class ProgramTaskHistory extends StatefulWidget {
  const ProgramTaskHistory({
    super.key,
    required this.controller,
    required this.conversationId,
    required this.child,
    this.empty,
  });
  final ChatController controller;
  final String conversationId;
  final Widget child;
  final Widget? empty;
  @override
  State<ProgramTaskHistory> createState() => _ProgramTaskHistoryState();
}

class _ProgramTaskHistoryState extends State<ProgramTaskHistory> {
  final List<Map<String, Object?>> _tasks = [];
  StreamSubscription<MiniappProgramChange>? _subscription;
  bool _loaded = false, _loading = false, _more = false;
  int _revision = 0;
  @override
  void initState() {
    super.initState();
    _subscription = MiniappProgramStore.changes.stream.listen((change) {
      if (change.conversationId == widget.conversationId) _load();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void didUpdateWidget(ProgramTaskHistory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) {
      _tasks.clear();
      _loaded = false;
      _load();
    }
  }

  Future<void> _load({bool append = false}) async {
    final revision = ++_revision;
    setState(() => _loading = true);
    await runUiAction(context, () async {
      final rows = await widget.controller.htmlStore.database.rawQuery(
        '''
        SELECT message_id, snapshot_json, MAX(version) AS version,
          created_at AS updated_at
        FROM html_game_events
        WHERE message_id IN (
          SELECT message_id FROM html_games WHERE conversation_id = ?
          AND message_id IN (
            SELECT id FROM messages WHERE kind = 'html_game'
            AND (json_extract(interactive_json, '\$.participation.audience') IS NULL
              OR EXISTS (SELECT 1 FROM json_each(interactive_json, '\$.participation.audience') WHERE value = 'user:local'))
            AND NOT EXISTS (SELECT 1 FROM json_each(interactive_json, '\$.participation.excludedAudience') WHERE value = 'user:local')
          )
        )
        AND json_type(snapshot_json, '\$.state.taskProgress') = 'object'
        GROUP BY message_id, json_extract(snapshot_json, '\$.state.taskProgress.title'),
          json_extract(snapshot_json, '\$.state.taskProgress.id')
        ORDER BY updated_at DESC, message_id DESC, version DESC
        LIMIT 30 OFFSET ?
      ''',
        [widget.conversationId, append ? _tasks.length : 0],
      );
      if (!mounted || revision != _revision) return;
      setState(() {
        if (!append) _tasks.clear();
        _tasks.addAll(rows);
        _more = rows.length == 30;
        _loaded = true;
      });
    });
    if (mounted && revision == _revision) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_loaded && _tasks.isEmpty && widget.empty != null) widget.empty!,
      for (final row in _tasks) _tile(row),
      if (_more)
        TextButton(
          onPressed: _loading ? null : () => _load(append: true),
          child: const Text('加载更多'),
        ),
      widget.child,
    ],
  );
  Widget _tile(Map<String, Object?> row) {
    final snapshot = jsonDecode(row['snapshot_json'] as String) as Map;
    final task = (snapshot['state'] as Map)['taskProgress'] as Map;
    final description = task['description'] as String?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: settingsFieldColor(context),
        borderRadius: BorderRadius.circular(26),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          title: Text(task['title'] as String),
          subtitle: description == null || description.isEmpty
              ? null
              : Text(description, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: const SettingsIcon(type: SettingsIconType.chevron),
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute(builder: (_) => _ProgramTaskDetail(task: task)),
          ),
        ),
      ),
    );
  }
}

class _ProgramTaskDetail extends StatelessWidget {
  const _ProgramTaskDetail({required this.task});
  final Map task;
  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: SettingsAppBar(
      title: task['title'] as String,
      onBack: () => Navigator.pop(context),
    ),
    body: ListView(
      padding: EdgeInsets.fromLTRB(
        24,
        settingsHeaderHeight(context) + 16,
        24,
        MediaQuery.paddingOf(context).bottom + 24,
      ),
      children: [
        if (task['description'] case final String description
            when description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(
              description,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        PrivateTaskListNodes(steps: (task['steps'] as List).cast<Map>()),
      ],
    ),
  );
}
