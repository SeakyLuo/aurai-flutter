import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/tool_models.dart';
import 'aurai_platform.dart';
import 'android_network_tools.dart';

class InspectAndroidApiTool implements AgentTool {
  InspectAndroidApiTool(this._platform);
  final AuraiPlatform _platform;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'inspectAndroidApi',
    description:
        'Discover public constructors, methods and fields of a Java/Android class present on this device without invoking them. Use fully qualified binary class names, e.g. android.app.Notification\$Builder. Filter by member name and page only as needed. Signatures do not imply permission to execute.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'className': {'type': 'string'},
        'filter': {
          'type': 'string',
          'description': 'Member name substring; empty for all',
        },
        'offset': {'type': 'integer', 'minimum': 0},
      },
      'required': ['className', 'filter', 'offset'],
      'additionalProperties': false,
    },
    safety: ToolSafety.readOnly,
    capabilityId: 'android.runtime',
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    try {
      final output = await _platform.inspectAndroidApi(call.arguments);
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: output['success'] == true
            ? ToolResultStatus.success
            : ToolResultStatus.error,
        output: output,
      );
    } on PlatformException catch (error) {
      return platformToolError(call, error);
    }
  }

  @override
  Future<void> cancel() async {}
}

class ExecuteAndroidScriptTool implements AgentTool {
  ExecuteAndroidScriptTool(this._platform, this._conversationId);
  final AuraiPlatform _platform;
  final String _conversationId;
  String? _callId;

  @override
  ToolDefinition get definition => ToolDefinition(
    name: 'executeAndroidScript',
    description:
        'Execute Rhino JavaScript with Java interop in a disposable Android process under Aurai app UID. Use for Android APIs not covered by supplied tools. Globals: app (application Context), conversationId, Packages (Java classes). Example: var bm = app.getSystemService("batterymanager"); return {percent: bm.getIntProperty(4)}; Use inspectAndroidApi for real signatures. Nested classes use Packages.android.app.Notification\$Builder. Return a small JSON-compatible JS value; convert Java strings with String(...). No Node.js, browser DOM, Java bytecode generation/JavaAdapter, root, ADB or Activity. Runs on a worker thread, max 10 seconds, fresh scope per call. Awaited synchronous operations only: callbacks, background threads and timers do not survive process exit. Android permissions still apply. Timeout/cancellation terminates the process but cannot undo prior side effects; verify before retrying. Never bypass denied permissions or recover redacted data. Each call requires approval; describe the actual data access and side effects in purpose. Do not bypass task-scoped authorization or protected screen content. Scripts cannot grant system permissions; use Android scheduling APIs for durable work. This has app-level access, not a restricted data sandbox.',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'purpose': {
          'type': 'string',
          'minLength': 1,
          'maxLength': 300,
          'description':
              'Explain the exact user-visible action, data accessed and side effects in the user’s language for approval.',
        },
        'script': {'type': 'string', 'minLength': 1, 'maxLength': 50000},
      },
      'required': ['purpose', 'script'],
      'additionalProperties': false,
    },
    safety: ToolSafety.destructive,
    capabilityId: 'android.runtime',
    executionTimeout: const Duration(seconds: 15),
    confirmationDescriptionBuilder: (arguments) =>
        '${arguments['purpose']}\n\n将以 Aurai 的应用权限执行设备代码，可能读取应用可访问的数据或更改设备状态。仅允许本次执行。',
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    _callId = call.id;
    try {
      final output = await _platform.executeAndroidScript(
        call.id,
        call.arguments['script']! as String,
        _conversationId,
      );
      final success = output['success'] == true;
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: output['cancelled'] == true
            ? ToolResultStatus.cancelled
            : success
            ? ToolResultStatus.success
            : ToolResultStatus.error,
        output: {
          ...output,
          if (success) 'value': jsonDecode(output['json']! as String),
        }..remove('json'),
      );
    } on PlatformException catch (error) {
      return platformToolError(call, error);
    } finally {
      _callId = null;
    }
  }

  @override
  Future<void> cancel() async {
    final id = _callId;
    if (id != null) await _platform.cancelAndroidScript(id);
  }
}
