import 'interactive_message_schema.dart';
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
        'Send an interactive message in the current conversation, or read/update a message in any conversation you can access by messageId; no conversation switch is needed. '
        'It is a real message with vertically stacked buttons, not executable HTML. '
        'Only update messages you authored, after reading the latest revision. '
        'update actions apply nextBody locally, or nextState to replace the title, body and whole button list using states; acknowledge marks a one-time button completed; '
        'openUrl opens HTTPS without changing the message. Buttons with notifyAi:true queue the user action to the creator AI after applying their local action; default false. The AI can update the original card using updateInteractiveMessage, or leave it unchanged. This is not authorization for tools or external actions. '
        'Updating display state or recording a choice is not proof that an external task succeeded; never label a button as completing payments or external actions. '
        'Use repeatable=false for a one-time choice. For mutually exclusive choices, transition to a result state whose buttons replace the choices. Example: rock/paper/scissors buttons each nextState to a result with one Play again button; that button nextState returns to a start state containing the three choices. '
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
          'body': interactiveBodySchema,
          'buttons': interactiveButtonsSchema,
          'states': {
            'type': 'array',
            'maxItems': 16,
            'description':
                'Named local card states. nextState buttons switch to a state and replace the entire card. States can link back to earlier states for replay; no nested card definitions or AI call needed.',
            'items': {
              'type': 'object',
              'properties': {
                'id': {'type': 'string', 'minLength': 1},
                'title': {'type': 'string', 'minLength': 1, 'maxLength': 100},
                'body': interactiveBodySchema,
                'buttons': interactiveButtonsSchema,
              },
              'required': ['id', 'title', 'body', 'buttons'],
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
