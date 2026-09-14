import '../domain/tool_models.dart';

class InteractiveMessageTool implements AgentTool, RuntimeCapabilityAgentTool {
  InteractiveMessageTool(this.name, this.run);
  final String name;
  final Future<Map<String, Object?>> Function(String, Map<String, Object?>) run;
  static const names = [
    'sendInteractiveMessage',
    'readInteractiveMessage',
    'updateInteractiveMessage',
  ];
  @override
  ToolDefinition get definition => ToolDefinition(
    name: name,
    capabilityId: 'local.messages',
    safety: name == 'readInteractiveMessage'
        ? ToolSafety.readOnly
        : ToolSafety.lowRisk,
    description:
        'Send, read or update an interactive message in the current conversation. '
        'It is a real message with vertically stacked buttons, not executable HTML. '
        'Only update messages you authored, after reading the latest revision. '
        'update actions apply nextBody locally; acknowledge marks a one-time button completed; '
        'openUrl opens HTTPS without changing the message. These buttons never execute tools, send messages, grant permissions or automatically wake AI. '
        'Updating display state or recording a choice is not proof that an external task succeeded; never label a button as completing payments or external actions. '
        'Use repeatable=false for a one-time choice. All buttons remain independent; do not present a vote requiring mutually exclusive choices. '
        'Actual updates append a system notice without waking other AIs. Do not repeat the card in ordinary text. '
        'messageId and button IDs are internal references; never ask users to enter them.',
    inputSchema: {
      'type': 'object',
      'properties': {
        if (name != 'sendInteractiveMessage') 'messageId': {'type': 'string'},
        if (name == 'updateInteractiveMessage')
          'revision': {'type': 'integer', 'minimum': 0},
        if (name != 'readInteractiveMessage') ...{
          'title': {'type': 'string', 'minLength': 1, 'maxLength': 100},
          'body': {'type': 'string', 'maxLength': 10000},
          'buttons': {
            'type': 'array',
            'minItems': 1,
            'maxItems': 12,
            'items': {
              'type': 'object',
              'properties': {
                'id': {'type': 'string', 'minLength': 1},
                'label': {'type': 'string', 'minLength': 1, 'maxLength': 80},
                'action': {
                  'type': 'string',
                  'enum': ['update', 'acknowledge', 'openUrl'],
                },
                'style': {
                  'type': 'string',
                  'enum': [
                    'normal',
                    'primary',
                    'info',
                    'warning',
                    'danger',
                    'success',
                  ],
                  'description':
                      'Optional visual emphasis: success is green, danger red, primary purple gradient with white text, info a separate light purple background with purple text; default normal. Prefer at most one primary action. Styling does not grant permissions or change what a button does.',
                },
                'icon': {
                  'type': 'string',
                  'enum': [
                    'none',
                    'info',
                    'play',
                    'reset',
                    'delete',
                    'check',
                    'open',
                    'settings',
                  ],
                  'description':
                      'Optional leading outline icon. Omit to choose from action; none hides it.',
                },
                'showArrow': {
                  'type': 'boolean',
                  'description': 'Optional trailing arrow. Defaults to false.',
                },
                'repeatable': {'type': 'boolean'},
                'disabled': {'type': 'boolean'},
                'completedLabel': {'type': 'string', 'maxLength': 80},
                'nextBody': {'type': 'string', 'maxLength': 10000},
                'url': {'type': 'string'},
              },
              'required': ['id', 'label', 'action', 'repeatable'],
              'additionalProperties': false,
            },
          },
        },
      },
      'required': [
        if (name != 'sendInteractiveMessage') 'messageId',
        if (name == 'updateInteractiveMessage') 'revision',
        if (name != 'readInteractiveMessage') ...['title', 'body', 'buttons'],
      ],
      'additionalProperties': false,
    },
  );
  @override
  Future<ToolResult> execute(ToolCall call) async {
    try {
      return ToolResult(
        callId: call.id,
        toolName: name,
        status: ToolResultStatus.success,
        output: await run(name, call.arguments),
      );
    } on Object catch (error) {
      return ToolResult(
        callId: call.id,
        toolName: name,
        status: ToolResultStatus.error,
        output: {
          'message': switch (error) {
            StateError() => error.message,
            ArgumentError() => error.message,
            _ => error.toString(),
          },
        },
      );
    }
  }

  @override
  Future<void> cancel() async {}
}
