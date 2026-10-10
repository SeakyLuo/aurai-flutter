import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';

/// Local notification scheduling, independent of AI execution and widget life.
class InteractiveReminders {
  static const _channel = MethodChannel(
    'com.haiskynology.aurai/interactive_reminders',
  );
  static final changes = StreamController<String>.broadcast();
  static bool _listening = false;
  static Future<Map<String, Object?>> read(
    String messageId,
    String actorId,
  ) async {
    if (!_listening) {
      _listening = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'changed') changes.add(call.arguments as String);
      });
    }
    final result = await _channel.invokeMapMethod<String, Object?>('read', {
      'messageId': messageId,
      'actorId': actorId,
    });
    return result!;
  }

  static Future<void> perform(
    String messageId,
    String actorId,
    Map<String, Object?> event,
  ) async {
    await _channel.invokeMethod<void>('apply', {
      ...event,
      'id': jsonEncode([messageId, actorId, event['key']]),
    });
  }

  static Future<void> permissions() =>
      _channel.invokeMethod<void>('permissions');
}
