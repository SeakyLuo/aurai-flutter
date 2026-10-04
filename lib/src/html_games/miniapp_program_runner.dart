import 'dart:convert';
import 'package:flutter/services.dart';
import 'miniapp_program.dart';

/// Executes isolated program code; persistence remains owned by the host.
abstract interface class MiniappProgramRunner {
  Future<Map<String, Object?>> run(String script, Map<String, Object?> input);
}

class PlatformMiniappProgramRunner implements MiniappProgramRunner {
  const PlatformMiniappProgramRunner();
  static const _channel = MethodChannel('com.haiskynology.aurai/platform');

  @override
  Future<Map<String, Object?>> run(
    String script,
    Map<String, Object?> input,
  ) async {
    final encoded = await _channel.invokeMethod<String>('runMiniappProgram', {
      'script': script,
      'input': jsonEncode(input),
    });
    return MiniappProgram.decode(encoded);
  }
}
