import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ScheduledTasks extends ChangeNotifier {
  final _channel = const MethodChannel(
    'com.haiskynology.aurai/scheduled_tasks',
  );
  List<Map<String, Object?>> tasks = [];
  bool allowed = false;
  String timezone = 'UTC';
  bool _managing = false;
  bool get supported => Platform.isAndroid;
  Future<void> initialize(Future<void> Function() onDue) async {
    if (!supported) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'due') unawaited(onDue());
      if (call.method == 'changed' && !_managing) await reload();
    });
    await reload();
    unawaited(onDue());
  }

  Future<void> reload() async {
    if (!supported) return;
    final data = (await _channel.invokeMapMethod<String, Object?>('list'))!;
    allowed = data['allowed']! as bool;
    timezone = data['timezone']! as String;
    tasks = (data['tasks']! as List)
        .map((e) => Map<String, Object?>.from(e as Map))
        .toList();
    tasks.sort((a, b) => (a['runAt'] as int).compareTo(b['runAt'] as int));
    notifyListeners();
  }

  Future<Map<String, Object?>> save(Map<String, Object?> data) async {
    final task = (await _channel.invokeMapMethod<String, Object?>(
      'save',
      data,
    ))!;
    await reload();
    return task;
  }

  Future<void> manage(String id, String action) async {
    _managing = true;
    try {
      await _channel.invokeMethod<void>('manage', {'id': id, 'action': action});
    } finally {
      _managing = false;
      await reload();
    }
  }

  Future<void> permission() => _channel.invokeMethod<void>('permission');
  Future<Map<String, Object?>?> take(bool busy) =>
      _channel.invokeMapMethod<String, Object?>('take', {'busy': busy});
  Future<void> finish(
    String id,
    String outcome,
    String? conversationId,
    String? error,
  ) async {
    await _channel.invokeMethod<void>('finish', {
      'id': id,
      'outcome': outcome,
      'conversationId': conversationId,
      'error': error,
    });
    await reload();
  }
}

String taskState(String state) => switch (state) {
  'scheduled' => '待执行',
  'starting' || 'running' => '执行中',
  'paused' => '已暂停',
  'completed' => '已完成',
  'cancelled' => '已停止',
  'missed' => '已错过',
  'interrupted' => '已中断',
  _ => '未完成',
};
String taskTime(int millis) {
  final time = DateTime.fromMillisecondsSinceEpoch(millis);
  return '${time.month}月${time.day}日 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}
