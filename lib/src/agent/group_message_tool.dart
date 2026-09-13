import '../domain/tool_models.dart';
import '../domain/message_image.dart';
import 'dart:convert';
import 'dart:io';

class GroupMessageTool implements AgentTool, RuntimeCapabilityAgentTool {
  GroupMessageTool(this.send);
  final Future<Map<String, Object?>> Function(Map<String, Object?>) send;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'sendGroupMessages',
    capabilityId: 'local.group_chats',
    safety: ToolSafety.lowRisk,
    description:
        'Publish one or several complete messages to this group as yourself. '
        'Use member IDs from the supplied roster for mentions and message IDs from '
        'the supplied history for quotes. Never invent IDs. If new messages arrived, '
        'nothing is sent and the new messages are returned: reconsider your draft, '
        'then retry or remain silent. Do not repeat already executed device actions. '
        'Only explicit instructions from the human user may change participation. '
        'paused stops automatic replies, active resumes them, unchanged preserves state. '
        'An empty messages array allows silence or participation changes.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'groupId': {
          'type': ['string', 'null'],
          'description':
              'Null uses the current group. In private chat supply a group ID discovered with listGroupChats/readGroupChat; only participation changes with empty messages are allowed there.',
        },
        'messages': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'text': {'type': 'string', 'minLength': 1},
              'mentionIds': {
                'type': 'array',
                'items': {'type': 'string'},
                'uniqueItems': true,
              },
              'quoteMessageId': {
                'type': ['string', 'null'],
              },
            },
            'required': ['text', 'mentionIds', 'quoteMessageId'],
            'additionalProperties': false,
          },
        },
        'participation': {
          'type': 'string',
          'enum': ['unchanged', 'paused', 'active'],
        },
      },
      'required': ['groupId', 'messages', 'participation'],
      'additionalProperties': false,
    },
  );

  @override
  Future<void> cancel() async {}

  @override
  Future<ToolResult> execute(ToolCall call) async {
    try {
      final output = await send(call.arguments);
      final images =
          (output.remove('_images') as List<MessageImage>?) ?? const [];
      final attachments = await Future.wait([
        for (final image in images)
          File(image.path).readAsBytes().then(
            (bytes) => ToolAttachment(
              type: ToolAttachmentType.image,
              mimeType: image.mimeType,
              base64Data: base64Encode(bytes),
            ),
          ),
      ]);
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.success,
        output: output,
        attachments: attachments,
      );
    } on ArgumentError catch (error) {
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.error,
        output: {'message': error.message},
      );
    }
  }
}
