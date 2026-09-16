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
    'clickInteractiveMessage',
  ];
  @override
  ToolDefinition get definition => ToolDefinition(
    name: name,
    capabilityId: 'local.messages',
    safety: name == 'readInteractiveMessage'
        ? ToolSafety.readOnly
        : ToolSafety.lowRisk,
    description:
        'Send, read, update or participate in a native interactive message. '
        'Read/click works in any conversation you can access without switching conversations. '
        'Each human or AI has independent state and choices; clicks never overwrite another participant. '
        'readInteractiveMessage returns your current card, participantRevision, permitted statistics and up to 50 history events. '
        'To participate, call clickInteractiveMessage with messageId, buttonId, revision and participantRevision from a fresh read. '
        'Your identity comes from the current AI runtime; participantId only selects a read-only perspective in readInteractiveMessage. '
        'Use beforeEvent to read older history using the last sequence. '
        'Only the author updates the shared definition; use its revision and definition fields from readInteractiveMessage. Omitted participation settings are preserved on update. '
        'update actions apply nextBody or nextState to your own card. acknowledge records a choice; repeatable=false completes that button for you. '
        'openUrl returns the HTTPS URL for an AI and opens it for a human. '
        'notifyAi queues a callback to the creator, respecting choice visibility. '
        'participation.visibility controls individual choices; summaryVisibility independently controls aggregate counts: public, private or afterClose. '
        'Defaults are public. closed=true ends participation and reveals afterClose results. '
        'selectionMode=singleChoice makes the latest choice each participant’s vote, allows changing it, and counts each participant once; use acknowledge buttons for a poll. '
        'Default actions mode supports games, branching states and repeated actions with full history. '
        'Author updates preserve all history, and everyone starts from the revised definition on their next action. '
        'Message and button IDs are internal; do not ask users to enter them. Do not repeat the card in ordinary text.',
    inputSchema: {
      'type': 'object',
      'properties': {
        if (name == 'clickInteractiveMessage') ...{
          'buttonId': {'type': 'string'},
          'participantRevision': {'type': 'integer', 'minimum': 0},
        },
        if (name == 'readInteractiveMessage') ...{
          'participantId': {
            'type': 'string',
            'description':
                'Optional read-only perspective; defaults to yourself.',
          },
          'beforeEvent': {'type': 'integer', 'minimum': 1},
        },
        if (name != 'sendInteractiveMessage') 'messageId': {'type': 'string'},
        if (name == 'updateInteractiveMessage' ||
            name == 'clickInteractiveMessage')
          'revision': {'type': 'integer', 'minimum': 0},
        if (name == 'sendInteractiveMessage' ||
            name == 'updateInteractiveMessage') ...{
          'participation': interactiveParticipationSchema,
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
        if (name == 'clickInteractiveMessage') ...[
          'buttonId',
          'revision',
          'participantRevision',
        ],
        if (name == 'sendInteractiveMessage' ||
            name == 'updateInteractiveMessage') ...[
          'title',
          'body',
          'buttons',
        ],
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
