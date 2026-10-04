import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../app/ui_action.dart';
import '../../html_games/miniapp_program_store.dart';
import 'chat_controller.dart';
import 'private_task_list.dart';
import 'private_task_list_nodes.dart';
import 'settings_appearance.dart';

/// Displays only the miniapp's public task projection, never its private state.
class ProgramTaskPanel extends StatefulWidget {
  const ProgramTaskPanel({
    super.key,
    required this.controller,
    required this.child,
    required this.conversationId,
    this.expanded = false,
    this.empty,
  });
  final ChatController controller;
  final Widget child;
  final String conversationId;
  final bool expanded;
  final Widget? empty;

  @override
  State<ProgramTaskPanel> createState() => _ProgramTaskPanelState();
}

class _ProgramTaskPanelState extends State<ProgramTaskPanel> {
  StreamSubscription<MiniappProgramChange>? _subscription;
  final _changes = StreamController<Map<String, dynamic>>.broadcast();
  Map<String, dynamic>? _progress;
  int _revision = 0;
  bool _loaded = false, _failed = false;
  late String _conversationId;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(ProgramTaskPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_conversationId != widget.conversationId) _listen();
  }

  void _listen() {
    _subscription?.cancel();
    _conversationId = widget.conversationId;
    _progress = null;
    _loaded = false;
    _failed = false;
    ++_revision;
    _changes.add({'steps': const <Map>[]});
    _subscription = MiniappProgramStore.changes.stream.listen((change) {
      if (change.conversationId == _conversationId) _load();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final revision = ++_revision;
    final conversationId = _conversationId;
    final success = await runUiAction(context, () async {
      final rows = await widget.controller.htmlStore.database.query(
        'html_games',
        columns: ['state_json'],
        where: '''conversation_id = ?
          AND json_type(state_json, '\$.taskProgress') IS NOT NULL
          AND message_id IN (SELECT id FROM messages WHERE kind = 'html_game'
            AND (json_extract(interactive_json, '\$.participation.audience') IS NULL
              OR EXISTS (SELECT 1 FROM json_each(interactive_json, '\$.participation.audience') WHERE value = 'user:local'))
            AND NOT EXISTS (SELECT 1 FROM json_each(interactive_json, '\$.participation.excludedAudience') WHERE value = 'user:local'))''',
        whereArgs: [conversationId],
        orderBy: 'updated_at DESC, message_id DESC',
        limit: 1,
      );
      if (!mounted || revision != _revision) return;
      final progress = rows.isEmpty
          ? null
          : (jsonDecode(rows.single['state_json'] as String)
                    as Map)['taskProgress']
                as Map<String, dynamic>?;
      setState(() => _progress = progress);
      _changes.add(progress ?? {'steps': const <Map>[]});
    });
    if (mounted && revision == _revision)
      setState(() {
        _loaded = true;
        _failed = !success;
      });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _changes.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    final hasProgress =
        progress != null && (progress['steps'] as List).isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.expanded && !_loaded)
          const Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          )
        else if (widget.expanded && _failed)
          TextButton(onPressed: _load, child: const Text('重试'))
        else if (!hasProgress && _loaded && widget.empty != null)
          widget.empty!
        else if (progress != null && (progress['steps'] as List).isNotEmpty)
          if (widget.expanded)
            Material(
              color: settingsFieldColor(context),
              borderRadius: BorderRadius.circular(26),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      progress['title'] as String,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    PrivateTaskListNodes(
                      steps: (progress['steps'] as List).cast<Map>(),
                    ),
                  ],
                ),
              ),
            )
          else
            TaskProgressList(
              steps: (progress['steps'] as List).cast<Map>(),
              changes: _changes.stream,
              title: progress['title'] as String,
              label: progress['title'] as String,
            ),
        widget.child,
      ],
    );
  }
}
