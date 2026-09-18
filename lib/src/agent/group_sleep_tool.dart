import '../domain/local_time.dart';
import '../domain/tool_models.dart';

class GroupSleepTool implements AgentTool, RuntimeCapabilityAgentTool {
  GroupSleepTool(this.sleep);
  final Future<DateTime?> Function(Duration duration, String draft) sleep;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'sleepGroupChat',
    description:
        'End your current group turn and choose when to check the conversation again. '
        'Leave a short private draft for your future self in draft; it is saved for your next turn, never sent automatically. Use an empty string to leave no draft. No message is sent. At wake-up read the latest history and decide whether to speak or sleep again. '
        'Ordinary messages accumulate while sleeping; a direct mention wakes you early. '
        'If the human user explicitly asks you to sleep, actually call this tool with a positive duration; a sleep reaction, a good-night message, or [[NO_REPLY]] does not put you to sleep. Follow any specified duration; otherwise choose an appropriate duration from context. Respect named exceptions (for example, everyone except one member). Prioritize this latest instruction over unfinished earlier chat tasks. '
        'Choose the duration yourself based on the conversation, not randomly. '
        '-1 cancels timed wake-ups and waits for a new message or mention; it does not permanently pause replies. '
        '0 ends this turn and immediately reconsiders the latest history; avoid repeated zero-second loops. '
        'The wake time is saved and restored when the app restarts. Stopping the group cancels it. '
        'Call this last, with no subsequent tool calls in the same turn.',
    capabilityId: 'local.group_chats',
    safety: ToolSafety.lowRisk,
    inputSchema: {
      'type': 'object',
      'properties': {
        'draft': {
          'type': 'string',
          'maxLength': 1000,
          'description':
              'Private unsent draft or one-sentence reminder for yourself when you wake. Reconsider it against the latest history before speaking.',
        },
        'seconds': {
          'type': 'integer',
          'minimum': -1,
          'maximum': 86400,
          'description':
              'Seconds until reconsidering: -1 waits for new messages without a timer, 0 reconsiders immediately, 1–86400 schedules a wake-up.',
        },
      },
      'required': ['seconds', 'draft'],
      'additionalProperties': false,
    },
  );

  @override
  Future<void> cancel() async {}

  @override
  Future<ToolResult> execute(ToolCall call) async {
    try {
      final seconds = call.arguments['seconds'];
      if (seconds is! int || seconds < -1 || seconds > 86400) {
        throw ArgumentError('睡眠时间必须为 -1 至 86400 秒的整数');
      }
      final draft = call.arguments['draft'];
      if (draft is! String || draft.length > 1000) {
        throw ArgumentError('休眠草稿必须为不超过 1000 字的文本');
      }
      final until = await sleep(Duration(seconds: seconds), draft);
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.success,
        output: {
          'sleeping': until != null,
          'waitingForNewMessage': seconds == -1,
          'wakeAt': until == null ? null : localIsoTime(until),
        },
      );
    } on Object catch (error) {
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.error,
        output: {
          'message': error is StateError ? error.message : error.toString(),
        },
      );
    }
  }
}
