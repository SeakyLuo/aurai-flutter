import 'dart:async';

import 'package:flutter/services.dart';

import '../domain/tool_models.dart';
import '../domain/ui_tool_actions.dart';
import 'android_network_tools.dart';
import 'aurai_platform.dart';

String _screenTaskDescription(String provider) =>
    '允许 Aurai 读取屏幕并发送给 $provider 分析，以及点击、输入、滚动和导航以完成你的请求。授权将持续有效，可随时在“设置 → 设备能力”中关闭“屏幕操作”。';

typedef AccessibilityRequester = Future<Map<String, Object?>> Function();

class WaitTool implements AgentTool {
  Completer<void>? _cancelled;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'wait',
    description:
        'Wait briefly for a UI or network transition before observing again.',
    inputSchema: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'seconds': <String, Object?>{
          'type': 'integer',
          'minimum': 1,
          'maximum': 10,
        },
      },
      'required': <String>['seconds'],
      'additionalProperties': false,
    },
    safety: ToolSafety.lowRisk,
    capabilityId: 'android.observe',
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    final cancelled = Completer<void>();
    _cancelled = cancelled;
    final seconds = call.arguments['seconds']! as int;
    final outcome = await Future.any<String>(<Future<String>>[
      Future<void>.delayed(Duration(seconds: seconds)).then((_) => 'elapsed'),
      cancelled.future.then((_) => 'cancelled'),
    ]);
    _cancelled = null;
    return ToolResult(
      callId: call.id,
      toolName: call.name,
      status: outcome == 'elapsed'
          ? ToolResultStatus.success
          : ToolResultStatus.cancelled,
      output: <String, Object?>{
        'waitedSeconds': seconds,
        'completed': outcome == 'elapsed',
      },
    );
  }

  @override
  Future<void> cancel() async {
    _cancelled?.complete();
  }
}

class RequestAccessibilityAccessTool implements AgentTool {
  RequestAccessibilityAccessTool(this._request);
  final AccessibilityRequester _request;
  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'requestAccessibilityAccess',
    waitsForUser: true,
    executionTimeout: Duration(seconds: 155),
    description:
        'Ask the user to enable Aurai accessibility access when UI observation or interaction is needed. Request once and wait for the user to return. Respect denial; choose another route or explain the limitation.',
    inputSchema: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{},
      'required': <String>[],
      'additionalProperties': false,
    },
    safety: ToolSafety.lowRisk,
    capabilityId: 'android.permissions',
  );
  @override
  Future<ToolResult> execute(ToolCall call) async => ToolResult(
    callId: call.id,
    toolName: call.name,
    status: ToolResultStatus.success,
    output: await _request(),
  );
  @override
  Future<void> cancel() async {}
}

class ObserveDeviceTool extends _PlatformTool {
  ObserveDeviceTool(super.platform);

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'observeDevice',
    description:
        'Observe the foreground app, Android device state, and the current accessibility UI tree when authorized. Observe before UI actions and again after launchApp, startIntent, openSettings or UI actions to verify the result. Use fresh state instead of historical app, node, screen, network or permission values.',
    inputSchema: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{},
      'required': <String>[],
      'additionalProperties': false,
    },
    safety: ToolSafety.readOnly,
    capabilityId: 'android.observe',
  );

  @override
  Future<Map<String, Object?>> invoke(ToolCall call) =>
      platform.observeDevice();
}

class CaptureScreenTool implements AgentTool {
  CaptureScreenTool(this._platform, this._providerLabel);

  final AuraiPlatform _platform;
  final String _providerLabel;

  @override
  ToolDefinition get definition => ToolDefinition(
    name: 'captureScreen',
    description:
        'Capture the current Android screen for visual inspection when the accessibility tree is insufficient. The image is attached to this tool result and is not stored in conversation history. Images are sensitive remote-model input requiring runtime-enforced user confirmation. Never bypass protected screen content.',
    inputSchema: const <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{},
      'required': <String>[],
      'additionalProperties': false,
    },
    safety: ToolSafety.sensitive,
    capabilityId: 'android.vision',
    taskScopedConfirmation: true,
    confirmationDescription: _screenTaskDescription(_providerLabel),
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    try {
      final raw = Map<String, Object?>.from(await _platform.captureScreen());
      final image = raw.remove('imageBase64') as String?;
      final mimeType = raw['mimeType'] as String?;
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.success,
        output: raw,
        attachments: image == null
            ? const <ToolAttachment>[]
            : <ToolAttachment>[
                ToolAttachment(
                  type: ToolAttachmentType.image,
                  mimeType: mimeType!,
                  base64Data: image,
                  detail: 'high',
                ),
              ],
      );
    } on PlatformException catch (error) {
      return platformToolError(call, error);
    }
  }

  @override
  Future<void> cancel() => _platform.cancelPendingInteraction();
}

class TapScreenTool implements AgentTool, PreflightAgentTool {
  TapScreenTool(this._platform, this._providerLabel);

  final AuraiPlatform _platform;
  final String _providerLabel;

  @override
  ToolDefinition get definition => ToolDefinition(
    name: 'tapScreen',
    description:
        'Tap one point from the latest captureScreen result. Coordinates are normalized within that captured target window: x and y are each at least 0 and less than 1. The screenshot is invalidated after one attempt. Observe again after every tap and never replay an uncertain tap. After two visual_changed/stale results, use accessibility nodes or ask the user instead of looping screenshots.',
    inputSchema: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'screenshotId': <String, Object?>{'type': 'string'},
        'observationId': <String, Object?>{'type': 'string'},
        'x': <String, Object?>{
          'type': 'number',
          'minimum': 0,
          'exclusiveMaximum': 1,
        },
        'y': <String, Object?>{
          'type': 'number',
          'minimum': 0,
          'exclusiveMaximum': 1,
        },
      },
      'required': <String>['screenshotId', 'observationId', 'x', 'y'],
      'additionalProperties': false,
    },
    safety: ToolSafety.sensitive,
    capabilityId: 'android.vision',
    taskScopedConfirmation: true,
    confirmationDescription: _screenTaskDescription(_providerLabel),
  );

  @override
  Future<ToolResult?> preflight(ToolCall call) async {
    try {
      final output = await _platform.preflightTapScreen(call.arguments);
      if (output['valid'] == true) return null;
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.error,
        output: output,
      );
    } on PlatformException catch (error) {
      return platformToolError(call, error);
    }
  }

  @override
  Future<ToolResult> execute(ToolCall call) async {
    try {
      final output = await _platform.tapScreen(call.id, call.arguments);
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: output['performed'] == true
            ? ToolResultStatus.success
            : ToolResultStatus.error,
        output: output,
      );
    } on PlatformException catch (error) {
      return platformToolError(call, error);
    }
  }

  @override
  Future<void> cancel() => _platform.cancelPendingInteraction();
}

class ActTool extends _PlatformTool {
  ActTool(super.platform, this._providerLabel, this.name);
  final String name;
  final String _providerLabel;

  @override
  ToolDefinition get definition => ToolDefinition(
    name: name,
    description:
        'Perform only ${uiToolActions[name]} as an Android UI action against the latest observed accessibility node. Pass observationId from the latest observe result. Re-observe after every action and verify the expected state before claiming success.',
    inputSchema: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'observationId': <String, Object?>{
          'type': 'string',
          'description':
              'observationId from the latest observeDevice UI result.',
        },
        if (name != 'goBack' && name != 'goHome')
          'nodeRef': <String, Object?>{
            'type': 'string',
            'description': 'Node ref from the latest observeDevice result.',
          },
        if (name == 'inputUiText')
          'text': <String, Object?>{
            'type': 'string',
            'description': 'Text to enter in the observed field.',
          },
      },
      'required': <String>[
        'observationId',
        if (name != 'goBack' && name != 'goHome') 'nodeRef',
        if (name == 'inputUiText') 'text',
      ],
      'additionalProperties': false,
    },
    safety: ToolSafety.sensitive,
    capabilityId: 'android.accessibility',
    taskScopedConfirmation: true,
    confirmationDescription: _screenTaskDescription(_providerLabel),
  );

  @override
  Future<Map<String, Object?>> invoke(ToolCall call) =>
      platform.act(call.id, uiActionArguments(name, call.arguments));
}

class FindAppsTool extends _PlatformTool {
  FindAppsTool(super.platform);
  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'findApps',
    description:
        'Find launchable Android apps visible to Aurai by human-readable app name.',
    inputSchema: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'query': <String, Object?>{'type': 'string'},
      },
      'required': <String>['query'],
      'additionalProperties': false,
    },
    safety: ToolSafety.readOnly,
    capabilityId: 'android.apps',
  );
  @override
  Future<Map<String, Object?>> invoke(ToolCall call) =>
      platform.findApps(call.arguments['query']! as String);
}

class LaunchAppTool extends _PlatformTool {
  LaunchAppTool(super.platform);
  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'launchApp',
    description:
        'Launch an installed app selected from findApps results. Observe again to verify the foreground app.',
    inputSchema: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'packageName': <String, Object?>{'type': 'string'},
      },
      'required': <String>['packageName'],
      'additionalProperties': false,
    },
    safety: ToolSafety.lowRisk,
    capabilityId: 'android.apps',
  );
  @override
  Future<Map<String, Object?>> invoke(ToolCall call) =>
      platform.launchApp(call.arguments['packageName']! as String);
}

class StartIntentTool extends _PlatformTool {
  StartIntentTool(super.platform);
  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'startIntent',
    description:
        'Start a general Android intent. The exact action, data, MIME type and extras are shown to the user before execution. Observe again afterwards to verify the expected state.',
    inputSchema: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'action': <String, Object?>{'type': 'string'},
        'data': <String, Object?>{
          'type': <String>['string', 'null'],
        },
        'mimeType': <String, Object?>{
          'type': <String>['string', 'null'],
        },
        'packageName': <String, Object?>{
          'type': <String>['string', 'null'],
        },
        'extras': <String, Object?>{
          'type': <String>['array', 'null'],
          'items': <String, Object?>{
            'type': 'object',
            'properties': <String, Object?>{
              'key': <String, Object?>{'type': 'string'},
              'value': <String, Object?>{'type': 'string'},
            },
            'required': <String>['key', 'value'],
            'additionalProperties': false,
          },
        },
      },
      'required': <String>[
        'action',
        'data',
        'mimeType',
        'packageName',
        'extras',
      ],
      'additionalProperties': false,
    },
    safety: ToolSafety.sensitive,
    capabilityId: 'android.intents',
  );
  @override
  Future<Map<String, Object?>> invoke(ToolCall call) =>
      platform.startIntent(call.arguments);
}

class OpenSettingsTool extends _PlatformTool {
  OpenSettingsTool(super.platform);
  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'openSettings',
    description:
        'Open a stable Android Settings screen. If the user must change a setting before work can continue, supply userAction to pause within this call until the user responds. Opening a page or the user reporting completion does not prove permission was granted; check actual state afterward. For navigation alone set userAction=null and reply briefly.',
    inputSchema: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'screen': <String, Object?>{
          'type': 'string',
          'enum': <String>[
            'settings',
            'wifi',
            'network',
            'vpn',
            'accessibility',
            'notificationAccess',
            'appDetails',
          ],
        },
      },
      'required': <String>['screen'],
      'additionalProperties': false,
    },
    safety: ToolSafety.lowRisk,
    capabilityId: 'android.settings',
  );
  @override
  Future<Map<String, Object?>> invoke(ToolCall call) =>
      platform.openSettings(call.arguments['screen']! as String);
}

class AppShellTool extends _PlatformTool {
  AppShellTool(super.platform);
  String? _callId;
  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'shell',
    description:
        'Run a command as the Aurai app UID. This is not adb shell or root and cannot access protected Android data or settings.',
    inputSchema: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'command': <String, Object?>{'type': 'string'},
      },
      'required': <String>['command'],
      'additionalProperties': false,
    },
    safety: ToolSafety.destructive,
    capabilityId: 'android.shell.app_uid',
  );
  @override
  Future<Map<String, Object?>> invoke(ToolCall call) async {
    final id = '${call.id}:${DateTime.now().microsecondsSinceEpoch}';
    _callId = id;
    try {
      return await platform.runAppShell(
        id,
        call.arguments['command']! as String,
      );
    } finally {
      _callId = null;
    }
  }

  @override
  Future<void> cancel() async {
    final id = _callId;
    if (id != null) await platform.cancelAppShell(id);
  }
}

abstract class _PlatformTool implements AgentTool {
  _PlatformTool(this.platform);
  final AuraiPlatform platform;
  Future<Map<String, Object?>> invoke(ToolCall call);
  @override
  Future<ToolResult> execute(ToolCall call) async {
    try {
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.success,
        output: await invoke(call),
      );
    } on PlatformException catch (error) {
      return platformToolError(call, error);
    }
  }

  @override
  Future<void> cancel() => platform.cancelPendingInteraction();
}
