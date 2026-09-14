import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:path_provider/path_provider.dart';

/// Serialized, rotating JSONL diagnostics; logging failure cannot fail a reply.
class ExecutionLog {
  static Future<void> _tail = Future.value();
  static Future<void> write(
    Map<String, Object?> event, {
    required String apiKey,
  }) {
    final write = _tail.then((_) async {
      final root = await getApplicationSupportDirectory();
      final folder = await Directory(
        '${root.path}/logs',
      ).create(recursive: true);
      final file = File('${folder.path}/execution.jsonl');
      if (await file.exists() && await file.length() >= 5 * 1024 * 1024) {
        final previous = File('${folder.path}/execution.previous.jsonl');
        if (await previous.exists()) await previous.delete();
        await file.rename(previous.path);
      }
      var line = jsonEncode({
        'time': DateTime.now().toUtc().toIso8601String(),
        ...event,
      });
      if (apiKey.isNotEmpty) line = line.replaceAll(apiKey, '[redacted]');
      await file.writeAsString('$line\n', mode: FileMode.append, flush: true);
    });
    _tail = write.catchError((Object error, StackTrace stack) {
      developer.log(
        'Failed to write execution log',
        name: 'aurai.diagnostics',
        error: error,
        stackTrace: stack,
      );
    });
    return _tail;
  }

  static Object? argumentShape(Object? value) => switch (value) {
    Map() => {
      for (final entry in value.entries)
        '${entry.key}': argumentShape(entry.value),
    },
    List() => {
      'type': 'array',
      'length': value.length,
      'items': value.take(4).map(argumentShape).toList(),
    },
    String() => {'type': 'string', 'length': value.length},
    null => 'null',
    _ => value.runtimeType.toString(),
  };
}
