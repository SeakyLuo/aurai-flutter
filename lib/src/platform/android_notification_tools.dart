import 'package:flutter/services.dart';

import '../domain/tool_models.dart';
import 'android_network_tools.dart';
import 'aurai_platform.dart';

class GetNotificationsTool
    implements AgentTool, PreflightAgentTool, RuntimeCapabilityAgentTool {
  GetNotificationsTool(this._platform);

  final AuraiPlatform _platform;

  @override
  ToolDefinition get definition => ToolDefinition(
    name: 'getNotifications',
    description:
        'Read a bounded recent window from Android notifications observed while Aurai notification access is connected. Sensitive verification, login-security, payment, transfer, and bank content is redacted on-device before model access. Use only when relevant to the task. Explain why before opening notificationAccess settings when missing. Respect coverageStart and partial: this is not a complete history, and absence outside the observed window proves nothing. Never recover redacted content using other tools.',
    inputSchema: const <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'lookbackMinutes': <String, Object?>{
          'type': 'integer',
          'minimum': 1,
          'maximum': 1440,
        },
        'limit': <String, Object?>{
          'type': 'integer',
          'minimum': 1,
          'maximum': 50,
        },
        'appName': <String, Object?>{
          'type': <String>['string', 'null'],
          'description':
              'Optional human-readable app name filter, or null for all apps.',
        },
      },
      'required': <String>['lookbackMinutes', 'limit', 'appName'],
      'additionalProperties': false,
    },
    safety: ToolSafety.lowRisk,
    capabilityId: 'android.notifications.observe',
  );

  @override
  Future<ToolResult?> preflight(ToolCall call) async {
    try {
      final state = await _platform.getNotificationAccessState();
      if (state['availability'] == 'available') {
        return null;
      }
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.error,
        output: <String, Object?>{
          ...state,
          'error': 'Notification observation is not currently available',
          'next': state['availability'] == 'permissionRequired'
              ? 'Use openSettings with notificationAccess and explain why access is needed'
              : 'Wait briefly, then retry once after Android reconnects the listener',
        },
      );
    } on PlatformException catch (error) {
      return platformToolError(call, error);
    }
  }

  @override
  Future<ToolResult> execute(ToolCall call) async {
    try {
      final output = await _platform.getNotifications(
        call.arguments['lookbackMinutes']! as int,
        call.arguments['limit']! as int,
        call.arguments['appName'] as String?,
      );
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: output['availability'] == 'available'
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
