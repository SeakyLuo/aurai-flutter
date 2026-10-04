import '../diagnostics/execution_log.dart';
import 'shared_interaction_schema.dart';
import 'interactive_message_schema.dart';
import '../domain/tool_models.dart';
import '../domain/message_lookup_error.dart';

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
            'Votes update the card without system receipts. The creator always reads live aggregates; individual choices follow visibility. interaction.reveal supplies default timing for other viewers; participation.visibilityTiming and summaryVisibilityTiming override it independently. visibilityImmediateActors/summaryVisibilityImmediateActors allow permitted early viewing. Register listeners through participation.callbackEvents: vote for each submission/change (source=interactionVote, operationType=submit|change); complete for completion/manual closure (source=interactionComplete, completionType=conditionMet|manualClose). Registered listeners receive events automatically; no additional enable switch. Both include current results allowed to creator and require no callbackEventId acknowledgment or participant waiting. Last vote may emit both in order. Keep completion reachable and gate result views on available context. '
            'This tool performs the operation directly. Keep message/button IDs internal and do not repeat the full card as ordinary text.',
      'readInteractiveMessage' =>
        'Read an accessible interactive message without switching conversations. Returns your current card, actionToken, eligibility, buttons/options, visible interactionView and up to 50 of your action-history events. Authors also receive revision and definition for editing. Reading does not submit anything. When you decide to participate and submitted=false, call clickInteractiveMessage; a text choice does not count. '
            'Use the current card supplied in chat context directly, or read it when missing/stale. interactionView contains phase, round, submitted, self and permitted results. Hidden opponents’ choices and runtime state are not available before reveal. '
            'For your own card, pass only messageId; omit participantId and beforeEvent or set them to JSON null. Never use an empty participantId or invent a pagination cursor. participantId changes only the read-only perspective; perspective.interactionView belongs to that participant, while actionToken and ownParticipation remain yours. Use the last history sequence as beforeEvent only for earlier events. messageId must identify the actual card, not an ordinary message asking you to read it. A parameter or message-type error does not mean the card needs to be resent.',
      'retryInteractiveCallback' =>
        'Retry your failed callback using messageId and callbackEventId from ownParticipation.callback. Reuses the same event; does not click the button again or repeat its local state changes. Only failed events can retry. Read current state after a status conflict.',
      'clickInteractiveMessage' =>
        'Perform one existing button action as the current AI, just like a human tap. Copy messageId, actionToken and button id from the current card in chat context or readInteractiveMessage. Do not construct or decode actionToken: the app checks card and participant versions atomically. Never retype, shorten or reconstruct message identifiers. '
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
          'actionToken': {
            'type': 'string',
            'description':
                'Copy exactly from the current card. Bound to this message, your identity and the observed versions; a stale token requires rereading before deciding again.',
          },
        },
        if (name == 'readInteractiveMessage') ...{
          'participantId': {
            'type': ['string', 'null'],
            'minLength': 1,
            'description':
                'Omit or use JSON null to read as yourself. For another perspective use a real participant ID from the roster. Empty string is invalid; this does not grant access to hidden choices.',
          },
          'beforeEvent': {
            'type': ['integer', 'null'],
            'minimum': 1,
            'description':
                'Omit or use JSON null on the first read. For earlier history, use the last sequence returned by the previous read; do not guess 1.',
          },
        },
        if (name != 'sendInteractiveMessage')
          'messageId': {
            'type': 'string',
            'description':
                'Copy the exact messageId returned by the card read or accessible chat history. Never shorten, reconstruct or guess it.',
          },
        if (name == 'updateInteractiveMessage')
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
        if (name == 'clickInteractiveMessage') ...['buttonId', 'actionToken'],
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
      if (name == 'readInteractiveMessage') {
        final participant = call.arguments['participantId'];
        if (participant != null &&
            (participant is! String || participant.trim().isEmpty)) {
          throw ArgumentError(
            'participantId 必须是真实成员标识，不能填空字符串。读取自己的卡片请省略此参数或传 JSON null；无需重新发卡。',
          );
        }
        final before = call.arguments['beforeEvent'];
        if (before != null && (before is! int || before < 1)) {
          throw ArgumentError(
            'beforeEvent 必须是上一页返回的正整数序号；首次读取请省略或传 JSON null。',
          );
        }
      }
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
          'message': error.toString(),
          if (error is MessageLookupError) ...{
            'code': error.code,
            'suggestion': error.code == 'message_not_found'
                ? '消息未找到不代表权限不足。重新核对最近读取结果中的 messageId；必要时从当前可访问的聊天记录重新查找行动卡，再读取最新卡片并原样使用返回的 messageId、buttonId 和版本。不要原样重试错误参数、猜测标识、要求重发卡片或修改权限。'
                : '你不是该会话的当前成员。请确认目标会话与成员资格；不要重复点击，也不要把访问限制当成卡片失效。',
          },
        },
      );
    }
  }

  @override
  Future<void> cancel() async {}
}
