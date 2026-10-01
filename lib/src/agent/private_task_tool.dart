import '../domain/tool_models.dart';
import '../storage/private_task_state.dart';

class PrivateTaskTool implements AgentTool, RuntimeCapabilityAgentTool {
  const PrivateTaskTool(this.store, this.name);
  final PrivateTaskState store;
  final String name;
  static const names = [
    'createGoal',
    'getGoal',
    'updateGoal',
    'createPlan',
    'updatePlan',
  ];

  @override
  ToolDefinition get definition => ToolDefinition(
    name: name,
    capabilityId: 'task.manage',
    safety: name == 'getGoal' ? ToolSafety.readOnly : ToolSafety.lowRisk,
    description: switch (name) {
      'createGoal' =>
        'Create a durable objective for a complex user task in this private chat. You may decide to use it yourself, within the user request. Provide concrete completion criteria. Only one unfinished goal is allowed. The runtime continues an active goal after a final answer; complete or block it when appropriate. There is no model-turn limit. Never create goals for ordinary small talk.',
      'getGoal' =>
        'Read the current objective, completion criteria, status, plan and model-turn usage in this private chat.',
      'updateGoal' =>
        'Update goal status and explain why. complete requires evidence that completion criteria are satisfied and all plan steps are complete. blocked reports the same blocking condition after attempting meaningful alternatives; use an identical blocker key for that condition. The runtime only blocks after three consecutive reports in distinct model turns. Do not manufacture retries when approval or user input is required; use askUser. Report active with progress to reset the blocking audit; paused stops execution; cancelled abandons it. active resumes a paused or blocked goal only when the user asks to continue. Never resume because of unrelated messages.',
      'createPlan' =>
        'Create an independent execution plan, with or without a goal. Use updatePlan for an existing unfinished plan. Steps use pending, in_progress or completed; at most one step is in_progress.',
      _ =>
        'Update the existing execution plan for this private task, preserving completed work. No approval is needed to maintain the plan. Steps use pending, in_progress or completed; at most one step can be in_progress. Can be used without a goal. An empty list clears the plan.',
    },
    inputSchema: {
      'type': 'object',
      'properties': {
        if (name == 'createGoal') ...{
          'objective': {'type': 'string', 'minLength': 1},
          'completionCriteria': {'type': 'string', 'minLength': 1},
        },
        if (name == 'updateGoal') ...{
          'status': {
            'type': 'string',
            'enum': ['active', 'complete', 'blocked', 'paused', 'cancelled'],
          },
          'reason': {'type': 'string', 'minLength': 1},
          'blocker': {
            'type': 'string',
            'description':
                'Stable condition key, required when reporting blocked. Reuse it only while the same condition prevents progress.',
          },
        },
        if (name == 'createPlan' || name == 'updatePlan') ...{
          'explanation': {'type': 'string'},
          'steps': {
            'type': 'array',
            'maxItems': 30,
            'items': {
              'type': 'object',
              'properties': {
                'step': {'type': 'string', 'minLength': 1},
                'status': {
                  'type': 'string',
                  'enum': ['pending', 'in_progress', 'completed'],
                },
              },
              'required': ['step', 'status'],
              'additionalProperties': false,
            },
          },
        },
      },
      'required': switch (name) {
        'createGoal' => ['objective', 'completionCriteria'],
        'updateGoal' => ['status', 'reason'],
        'createPlan' || 'updatePlan' => ['explanation', 'steps'],
        _ => <String>[],
      },
      'additionalProperties': false,
    },
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    final args = call.arguments;
    final state = name == 'getGoal'
        ? await store.read()
        : await store.change((state) {
            if (name == 'createGoal') {
              if (state['objective'] != null &&
                  !['complete', 'cancelled'].contains(state['status'])) {
                throw StateError('已有未结束的目标，请先完成或取消');
              }
              final plan = state['objective'] == null ? state['steps'] : null;
              state.clear();
              state.addAll({
                'objective': args['objective'],
                'completionCriteria': args['completionCriteria'],
                'status': 'active',
                'turns': 0,
                'steps': plan ?? <Object>[],
                'reason': '',
              });
            } else if (name == 'updateGoal') {
              if (state['objective'] == null) throw StateError('当前没有目标');
              final status = args['status'] as String;
              if (![
                'active',
                'complete',
                'blocked',
                'paused',
                'cancelled',
              ].contains(status)) {
                throw ArgumentError('目标状态无效');
              }
              if (status == 'active') {
                if (['complete', 'cancelled'].contains(state['status'])) {
                  throw StateError('已结束的目标不能恢复，请创建新目标');
                }
                state.remove('blocker');
                state.remove('blockerCount');
                state.remove('blockerTurn');
              }
              if (status == 'blocked') {
                final blocker = (args['blocker'] as String? ?? '').trim();
                if (blocker.isEmpty) throw ArgumentError('请提供具体的阻塞条件');
                final turn = state['turns'] as int;
                final same = state['blocker'] == blocker;
                final count = same ? state['blockerCount'] as int : 0;
                state['blockerCount'] = same && state['blockerTurn'] == turn
                    ? count
                    : count + 1;
                state['blocker'] = blocker;
                state['blockerTurn'] = turn;
                state['reason'] = args['reason'];
                if ((state['blockerCount'] as int) < 3) {
                  state['status'] = 'active';
                  return;
                }
              }
              if (status == 'complete' &&
                  (state['steps'] as List).any(
                    (s) => s['status'] != 'completed',
                  )) {
                throw StateError('计划还有未完成步骤，请先更新计划');
              }
              state['status'] = status;
              state['reason'] = args['reason'];
            } else {
              if (name == 'createPlan' &&
                  (state['steps'] as List? ?? const []).any(
                    (s) => s['status'] != 'completed',
                  )) {
                throw StateError('已有未完成的计划，请使用 updatePlan');
              }
              if (name == 'updatePlan' && !state.containsKey('steps')) {
                throw StateError('当前没有计划，请先使用 createPlan');
              }
              final steps = (args['steps'] as List).cast<Map>();
              if (steps.length > 30 ||
                  steps.where((s) => s['status'] == 'in_progress').length > 1 ||
                  steps.any(
                    (s) =>
                        (s['step'] as String).trim().isEmpty ||
                        ![
                          'pending',
                          'in_progress',
                          'completed',
                        ].contains(s['status']),
                  )) {
                throw ArgumentError('计划最多 30 步，同时只能有一步进行中');
              }
              state['steps'] = steps;
              state['explanation'] = args['explanation'];
            }
          });
    return ToolResult(
      callId: call.id,
      toolName: name,
      status: ToolResultStatus.success,
      output: {'task': state},
    );
  }

  @override
  Future<void> cancel() async {}
}
