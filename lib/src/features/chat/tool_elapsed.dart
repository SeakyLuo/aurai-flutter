import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'task_elapsed.dart';

bool toolShowsElapsed(String? toolName, {String? resultJson}) {
  // User response and permission waits do not measure tool execution time.
  if (const {
    'askUser',
    'requestAccessibilityAccess',
    'requestShizukuAccess',
    'startNetworkCapture',
    'requestDocumentFolder',
    'requestModelProviderKey',
  }.contains(toolName)) {
    return false;
  }
  return resultJson == null ||
      !(jsonDecode(resultJson) as Map).containsKey('userAction');
}

class ToolElapsed extends StatefulWidget {
  const ToolElapsed({
    super.key,
    required this.startedAt,
    required this.finishedAt,
    this.fontSize = 12,
  });

  final DateTime startedAt;
  final DateTime? finishedAt;
  final double fontSize;

  @override
  State<ToolElapsed> createState() => _ToolElapsedState();
}

class _ToolElapsedState extends State<ToolElapsed> {
  Timer? _timer;

  Duration get _elapsed =>
      (widget.finishedAt ?? DateTime.now()).difference(widget.startedAt);

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(ToolElapsed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startedAt != widget.startedAt ||
        oldWidget.finishedAt != widget.finishedAt) {
      _timer?.cancel();
      _startTimer();
    }
  }

  void _startTimer() {
    if (widget.finishedAt != null) return;
    final remaining = 1001 - _elapsed.inMilliseconds;
    _timer = Timer(
      Duration(milliseconds: remaining > 0 ? remaining : 1000),
      () {
        setState(() {});
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          setState(() {});
        });
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = _elapsed;
    if (elapsed.inMilliseconds <= 1000) return const SizedBox.shrink();
    final duration = taskDuration(elapsed);
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Semantics(
        label: '${widget.finishedAt == null ? '已运行' : '用时'} $duration',
        child: Text(
          duration,
          style: TextStyle(
            fontSize: widget.fontSize,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
