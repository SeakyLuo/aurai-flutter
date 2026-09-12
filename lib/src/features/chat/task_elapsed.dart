import 'dart:async';
import 'package:flutter/material.dart';

String taskDuration(Duration duration) => [
  if (duration.inHours > 0) '${duration.inHours}小时',
  if (duration.inMinutes > 0) '${duration.inMinutes.remainder(60)}分钟',
  '${duration.inSeconds.remainder(60)}秒',
].join(' ');

class TaskElapsed extends StatefulWidget {
  const TaskElapsed({super.key, required this.watch, required this.failed});
  final Stopwatch watch;
  final bool failed;
  @override
  State<TaskElapsed> createState() => _TaskElapsedState();
}

class _TaskElapsedState extends State<TaskElapsed> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    if (widget.watch.isRunning) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!widget.watch.isRunning) timer.cancel();
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 48,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${widget.watch.isRunning ? '已处理' : '用时'} ${taskDuration(widget.watch.elapsed)}${widget.failed ? ' · 未完成' : ''}',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        const SizedBox(height: 12),
      ],
    ),
  );
}
