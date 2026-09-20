import '../diagnostics/execution_log.dart';
import 'shared_interaction_schema.dart';
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
    'retryInteractiveCallback',
  ];
  @override
  ToolDefinition get definition => ToolDefinition(
    name: name,
    capabilityId: 'local.messages',
    safety: name == 'readInteractiveMessage'
        ? ToolSafety.readOnly
        : ToolSafety.lowRisk,
    description: switch (name) {
      'sendInteractiveMessage' =>
        'Create a native interactive card in the current conversation or an accessible conversation specified by conversationId, without switching conversations. Omit conversationId to use the current conversation. In the current private chat it is inserted into your current streamed reply at this point; continue ordinary text afterwards only when useful. Do not describe an inline card as a separate message or repeat its contents. In another conversation or group chat it is a separate message sent as you. Use for persistent choices, shared participation and replayable rounds; ordinary one-off questions can use askUser. '
            'Set buttonColumns=2 for compact short-option polls or quizzes; omit for a single column. For shared interactions define interaction (state, completion rules, reveal timing and views) and submit buttons with JSON value. Each actor contributes one current-round submission. For radio/checkbox choices, put selection:{mode:single|multiple,options:[{id,label,value?}]} on one submit button. Its label is the confirmation action. Set interaction (for example allowChange:true) to store choices; do not create one submit button per option. A single selection records its option value, multiple records an array; selections retains option IDs and labels. Distribution counts each chosen option separately, with participant count as denominator. '
            'The app settles rules atomically; distribution/text/metric views render visible state. A poll and simultaneous-choice game use this same mechanism. nextRound keeps shared state and resets submissions plus roundInitial fields. '
            'notifyAi=true locks only the triggering button until its callback result. A later state-changing action supersedes the previous callback. Complete it with updateInteractiveMessage plus callbackEventId; a plain chat reply is not a card result. update/nextState buttons change only the acting participant’s presentation. openUrl opens/returns HTTPS; notifyAi requests a creator callback. Every button requires id,label,action,repeatable. '
            'Default visibility is public. reveal=onComplete hides other choices, aggregates and runtime state until completed or closed. Keep completion reachable and gate result views on available context. '
            'For complete examples, discover the public skill 共享交互消息 with listSkills/readSkill. Keep message/button IDs internal and do not repeat the full card as ordinary text.',
      'readInteractiveMessage' =>
        'Read an accessible interactive message without switching conversations. Returns your current card, revision, participantRevision, definition, visible interactionView and up to 50 of your action-history events. '
            'Read before clicking; interactionView contains phase, round, submitted, self and permitted results. Hidden opponents’ choices and runtime state are not available before reveal. '
            'participantId changes only the read-only perspective; perspective.interactionView belongs to that participant, while top-level revisions and ownParticipation remain yours. Use the last history sequence as beforeEvent for earlier events.',
      'retryInteractiveCallback' =>
        'Retry your failed callback using messageId and callbackEventId from ownParticipation.callback. Reuses the same event; does not click the button again or repeat its local state changes. Only failed events can retry. Read current state after a status conflict.',
      'clickInteractiveMessage' =>
        'Perform one existing button action as the current AI, just like a human tap. Pass messageId, buttonId, revision and participantRevision from a fresh readInteractiveMessage. '
            'submit records or replaces only your current-round choice. nextRound works after completion; it preserves shared state and clears round submissions. No participant impersonation parameter is needed. '
            'On a stale-state error, read again and decide against the new phase; do not blindly replay an old choice into a new round. Success returns your visible updated state; openUrl also returns its URL.',
      _ =>
        'When responding to a callback, attach callbackEventId and supply its participant result title/body/buttons; do not change shared rules in that call. Duplicate completion is ignored. Otherwise update a card you authored, using the current revision and definition from readInteractiveMessage. Supply title,body,buttons; omitted interaction/states/participation fields remain in place, and supplied participation fields merge. '
            'Preserves participants, shared runtime and action history. initial initializes only creation; roundInitial applies on the next round. Rules may change but a completed round is not settled again. '
            'participation.closed=true stops collecting and reveals onComplete submissions. Completion rules run only if their expression is true; reference closed explicitly when settlement should occur at closure. Do not replace the card merely to count votes: submit already stores choices and distribution renders them.',
    },
    inputSchema: {
      'type': 'object',
      'properties': {
        if (name == 'sendInteractiveMessage')
          'conversationId': {
            'type': 'string',
            'description':
                'Optional destination from searchConversations/listGroupChats. You must be a current member. Omit for the current conversation; never ask the user to enter IDs.',
          },
        if (name == 'retryInteractiveCallback' ||
            name == 'updateInteractiveMessage')
          'callbackEventId': {
            'type': 'string',
            'description':
                'For callback completion: eventId received in the callback context. Updates only the triggering participant title/body/buttons and atomically completes that event; do not send interaction/participation/states. Retrying an already committed result does not apply it twice.',
          },
        if (name == 'clickInteractiveMessage') ...{
          'value': {
            'description':
                'For selection submit buttons: option id for single, array of option ids for multiple. The host resolves configured values and records labels. For HTML input-enabled endpoints: text or JSON (max 16 KB). Omit for ordinary fixed buttons.',
          },
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
          'showStatistics': interactiveStatisticsSchema,
          'buttonColumns': interactiveButtonColumnsSchema,
          'participation': interactiveParticipationSchema,
          'interaction': sharedInteractionSchema,
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
                'showStatistics': interactiveStatisticsSchema,
                'buttonColumns': interactiveButtonColumnsSchema,
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
        if (name == 'retryInteractiveCallback') 'callbackEventId',
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
      final required = definition.inputSchema['required'] as List;
      for (final key in required) {
        if (!call.arguments.containsKey(key) || call.arguments[key] == null) {
          throw ArgumentError('缺少必填参数 $key，请按工具定义补齐后重试');
        }
      }
      for (final key in [
        'messageId',
        'title',
        'body',
        'callbackEventId',
        'buttonId',
      ]) {
        if (call.arguments.containsKey(key) && call.arguments[key] is! String) {
          throw ArgumentError('$key 必须是字符串');
        }
      }
      if (call.arguments.containsKey('buttons') &&
          call.arguments['buttons'] is! List) {
        throw ArgumentError('buttons 必须是按钮对象数组，不是序列化后的字符串');
      }
      return ToolResult(
        callId: call.id,
        toolName: name,
        status: ToolResultStatus.success,
        output: await run(name, call.arguments),
      );
    } on Object catch (error, stack) {
      await ExecutionLog.toolException(call.name, call.id, error, stack);
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
