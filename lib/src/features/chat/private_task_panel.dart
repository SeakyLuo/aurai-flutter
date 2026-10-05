import 'dart:async';
import 'package:flutter/material.dart';

import '../../app/ui_action.dart';
import '../../storage/private_task_state.dart';
import 'private_task_list_nodes.dart';
import 'settings_appearance.dart';

/// The private task page reads the same persisted checklist as the chat header.
class PrivateTaskPanel extends StatefulWidget {
  const PrivateTaskPanel({super.key, required this.store, this.empty});
  final PrivateTaskState store;
  final Widget? empty;

  @override
  State<PrivateTaskPanel> createState() => _PrivateTaskPanelState();
}

class _PrivateTaskPanelState extends State<PrivateTaskPanel> {
  StreamSubscription<Map<String, dynamic>>? _changes;
  Map<String, dynamic> _state = {};
  int _revision = 0;
  bool _loaded = false, _failed = false;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(PrivateTaskPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store.conversationId != widget.store.conversationId ||
        oldWidget.store.senderId != widget.store.senderId) {
      _listen();
    }
  }

  void _listen() {
    _changes?.cancel();
    ++_revision;
    _loaded = false;
    _failed = false;
    _state = {};
    _changes = widget.store.changes.listen((state) {
      ++_revision;
      setState(() {
        _state = state;
        _loaded = true;
        _failed = false;
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final revision = ++_revision;
    setState(() => _failed = false);
    final succeeded = await runUiAction(context, () async {
      final state = await widget.store.read();
      if (!mounted || revision != _revision) return;
      setState(() {
        _state = state;
        _loaded = true;
      });
    });
    if (mounted && revision == _revision && !succeeded) {
      setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Center(
        child: TextButton(onPressed: _load, child: const Text('重试')),
      );
    }
    if (!_loaded) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final steps = (_state['steps'] as List? ?? const []).cast<Map>();
    if (steps.isEmpty) return widget.empty ?? const SizedBox.shrink();
    final explanation = _state['explanation'] as String?;
    return Material(
      color: settingsFieldColor(context),
      borderRadius: BorderRadius.circular(26),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '任务清单',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (explanation != null && explanation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                explanation,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            PrivateTaskListNodes(steps: steps),
          ],
        ),
      ),
    );
  }
}
