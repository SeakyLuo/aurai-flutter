import 'package:flutter/services.dart';

import '../domain/tool_models.dart';
import 'aurai_platform.dart';

class SendNotificationTool implements AgentTool {
  SendNotificationTool(this._platform, this._conversationId);

  final AuraiPlatform _platform;
  final String _conversationId;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'sendNotification',
    description:
        'Send an immediate Android notification to the user on this device. Use when requested or when a task needs the user’s attention. Tapping opens this conversation. This does not schedule future reminders. If notifications are disabled, report that and do not claim delivery.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'title': {'type': 'string', 'minLength': 1, 'maxLength': 120},
        'body': {'type': 'string', 'minLength': 1, 'maxLength': 4000},
      },
      'required': ['title', 'body'],
      'additionalProperties': false,
    },
    safety: ToolSafety.lowRisk,
    capabilityId: 'android.notifications.send',
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    try {
      final output = await _platform.sendNotification(
        call.arguments['title']! as String,
        call.arguments['body']! as String,
        _conversationId,
      );
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: output['sent'] == true
            ? ToolResultStatus.success
            : ToolResultStatus.error,
        output: output,
      );
    } on PlatformException catch (error) {
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.error,
        output: {'code': error.code, 'message': error.message},
      );
    }
  }

  @override
  Future<void> cancel() async {}
}
