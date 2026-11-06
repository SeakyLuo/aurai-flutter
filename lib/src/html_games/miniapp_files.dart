import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'html_app_store.dart';

/// Media stays in the native app-scoped library; only metadata crosses the bridge.
class MiniappFiles {
  static const _channel = MethodChannel('com.haiskynology.aurai/platform');

  static Future<Map<String, Object?>> invoke(
    Database database,
    String appId,
    Map<String, Object?> args,
  ) async {
    await HtmlAppStore.load(database, appId);
    final action = args['action'] as String;
    if (!const [
      'info',
      'status',
      'import',
      'query',
      'record',
      'document',
    ].contains(action)) {
      throw ArgumentError('Unsupported file operation: $action');
    }
    final result = await _channel.invokeMethod<String>(
      'miniappFiles',
      jsonEncode({...args, 'appId': appId}),
    );
    return (jsonDecode(result!) as Map).cast<String, Object?>();
  }
}
