import '../domain/tool_models.dart';
import 'scheduled_tasks.dart';

class ScheduleTaskTool implements AgentTool, RuntimeCapabilityAgentTool {
  ScheduleTaskTool(
    this.tasks,
    this.conversationId,
    this.operation, {
    required this.senderId,
  });
  final String senderId;
  final String operation;
  static const operations = [
    'create',
    'update',
    'list',
    'pause',
    'resume',
    'delete',
  ];
  final ScheduledTasks tasks;
  final String conversationId;
  @override
  ToolDefinition get definition => ToolDefinition(
    name: '${operation}ScheduledTask${operation == 'list' ? 's' : ''}',
    description:
        'Perform only $operation on persistent Android scheduled AI tasks. Current local time: ${DateTime.now().toIso8601String()} with UTC offset ${DateTime.now().timeZoneOffset}; device timezone ${tasks.timezone}. Use only when user requests scheduling. Use listScheduledTasks to find existing tasks when needed; reuse a known task id instead of querying again without reason. A task runs the saved prompt using the current model and tools, producing a result conversation. Ask missing essential time details with askUser. Creation and update require a future ISO8601 runAt with explicit UTC offset, IANA timezone, RFC5545 recurrence body rrule (without RRULE: prefix; empty string for one-shot), and accurate human-readable Chinese scheduleLabel. Supports RFC5545 minute/hour/day/week/month/year intervals and selectors, not secondly. The start time must match the rule. Include sufficient details in prompt to execute independently; never claim ticket availability or success in advance. On permission errors guide user to Tasks page to enable precise scheduling; do not claim saved. At execution do the work, do not schedule it again. Deletion only if explicitly requested. Use this for reminders, recurring work and future monitoring; never substitute a clock alarm or an immediate notification. Only claim creation/update after persistence succeeds. Describe schedules without exposing rule syntax or task IDs. Scheduled execution grants no extra permissions and cannot guarantee purchases.',
    inputSchema: {
      'type': 'object',
      'properties': {
        if (operation != 'create' && operation != 'list')
          'id': {'type': 'string'},
        if (operation == 'create' || operation == 'update') ...{
          'title': {'type': 'string', 'maxLength': 80},
          'prompt': {'type': 'string', 'maxLength': 4000},
          'runAt': {'type': 'string'},
          'rrule': {'type': 'string'},
          'timezone': {'type': 'string'},
          'scheduleLabel': {'type': 'string'},
        },
      },
      'required': [
        if (operation != 'create' && operation != 'list') 'id',
        if (operation == 'create' || operation == 'update') ...[
          'title',
          'prompt',
          'runAt',
          'rrule',
          'timezone',
          'scheduleLabel',
        ],
      ],
      'additionalProperties': false,
    },
    safety: operation == 'list' ? ToolSafety.readOnly : ToolSafety.lowRisk,
    capabilityId: 'android.scheduled_tasks',
  );
  @override
  Future<ToolResult> execute(ToolCall call) async {
    try {
      final a = call.arguments;
      Object? output;
      bool owned(Map<String, Object?> task) =>
          (task['aiSenderId'] ?? 'agent:aurai') == senderId;
      if (operation != 'list' && operation != 'create') {
        await tasks.reload();
        if (!tasks.tasks.any((task) => task['id'] == a['id'] && owned(task)))
          throw StateError('任务不属于当前 AI 或已不存在');
      }
      switch (operation) {
        case 'list':
          await tasks.reload();
          output = {
            'tasks': tasks.tasks.where(owned).toList(),
            'allowed': tasks.allowed,
          };
        case 'create' || 'update':
          final at = DateTime.parse(a['runAt'] as String);
          if (!RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(a['runAt'] as String))
            throw StateError('执行时间必须包含时区偏移');
          output = await tasks.save({
            ...a,
            'runAt': at.millisecondsSinceEpoch,
            'sourceConversationId': conversationId,
            'aiSenderId': senderId,
            'requestKey': '$conversationId:${call.id}',
          });
        case 'pause' || 'resume' || 'delete':
          await tasks.manage(a['id'] as String, operation);
          output = {'updated': true};
        default:
          throw StateError('未知任务操作');
      }
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.success,
        output: {'result': output},
      );
    } on Object catch (error) {
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.error,
        output: {'message': error.toString()},
      );
    }
  }

  @override
  Future<void> cancel() async {}
}
