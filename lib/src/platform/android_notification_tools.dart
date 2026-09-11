import 'package:flutter/services.dart';

import '../domain/tool_models.dart';
import 'android_network_tools.dart';
import 'aurai_platform.dart';

class GetNotificationsTool
    implements
        AgentTool,
        PreflightAgentTool,
        RuntimeCapabilityAgentTool,
        ScopedAuthorizationAgentTool {
  GetNotificationsTool(this._platform, this._providerLabel);

  final AuraiPlatform _platform;
  final String _providerLabel;
  late int _listenerEpoch;

  @override
  ToolDefinition get definition => ToolDefinition(
    name: 'getNotifications',
    description:
        'Read a bounded recent window from Android notifications observed while Aurai notification access is connected. Sensitive verification, login-security, payment, transfer, and bank content is redacted on-device before model access.',
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
    safety: ToolSafety.sensitive,
    capabilityId: 'android.notifications.observe',
    taskScopedConfirmation: true,
    confirmationDescriptionBuilder: (arguments) {
      final appName = arguments['appName'] as String?;
      final target = appName == null ? '所有应用' : appName;
      return 'Aurai 将读取最近 ${arguments['lookbackMinutes']} 分钟内最多 '
          '${arguments['limit']} 条$target通知，经手机端敏感信息隐藏后发送给 '
          '$_providerLabel。本授权只在当前任务及上述范围内有效。';
    },
  );

  @override
  Future<ToolResult?> preflight(ToolCall call) async {
    try {
      final state = await _platform.getNotificationAccessState();
      if (state['availability'] == 'available') {
        _listenerEpoch = state['listenerEpoch']! as int;
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
  Object authorizationScope(ToolCall call) => <String, Object?>{
    'provider': _providerLabel,
    'listenerEpoch': _listenerEpoch,
    'lookbackMinutes': call.arguments['lookbackMinutes']! as int,
    'limit': call.arguments['limit']! as int,
    'appName': call.arguments['appName'] as String?,
  };

  @override
  bool authorizationCovers(Object grantedScope, Object requestedScope) {
    final granted = grantedScope as Map<String, Object?>;
    final requested = requestedScope as Map<String, Object?>;
    final grantedApp = granted['appName'] as String?;
    final requestedApp = requested['appName'] as String?;
    final appCovered =
        grantedApp == null ||
        (requestedApp != null &&
            grantedApp.toLowerCase() == requestedApp.toLowerCase());
    return granted['provider'] == requested['provider'] &&
        granted['listenerEpoch'] == requested['listenerEpoch'] &&
        (granted['lookbackMinutes']! as int) >=
            (requested['lookbackMinutes']! as int) &&
        (granted['limit']! as int) >= (requested['limit']! as int) &&
        appCovered;
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
