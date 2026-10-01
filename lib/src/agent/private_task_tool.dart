import '../domain/tool_models.dart';
import '../storage/private_task_state.dart';

class PrivateTaskTool implements AgentTool, RuntimeCapabilityAgentTool {
  const PrivateTaskTool(this.store, this.name);
  final PrivateTaskState store;
  final String name;
  static const names = [
    'createGoal',
    'getGoal',
    'getTaskList',
    'updateGoal',
    'createTaskList',
    'updateTaskList',
  ];

  @override
  ToolDefinition get definition => ToolDefinition(
    name: name,
    capabilityId: 'task.manage',
    safety: name == 'getGoal' || name == 'getTaskList'
        ? ToolSafety.readOnly
        : ToolSafety.lowRisk,
    description: switch (name) {
      'createGoal' =>
        'Create a durable objective only when explicitly requested by the user or system instructions. Do not infer goals from ordinary tasks. Include concrete completion criteria in the objective text. Only one unfinished goal is allowed. The runtime continues an active goal after a final answer; complete or block it when appropriate. There is no model-turn limit. Omit tokenBudget unless the user explicitly requested a concrete token budget for this goal; never estimate, recommend, or choose one yourself.',
      'getGoal' =>
        'Read your current objective, status and model-turn usage in this conversation. Available in private chats and groups; each AI owns its own state.',
      'getTaskList' =>
        'Read the current progress checklist and its explanation, independently of the goal.',
      'updateGoal' =>
        'Update goal status and explain why. complete requires evidence that completion criteria are satisfied. blocked reports the same blocking condition after attempting meaningful alternatives; use an identical blocker key for that condition. The runtime only blocks after three consecutive reports in distinct model turns. Do not manufacture retries when approval or user input is required; use askUser. Report active with progress to reset the blocking audit; paused stops execution. active resumes a paused or blocked goal only when the user asks to continue. Never resume because of unrelated messages.',
      'createTaskList' =>
        'Create a task list when work has multiple meaningful steps or will take enough time that visible progress helps the user. Skip simple requests. Keep items concise and outcome-oriented, with pending, in_progress or completed status and at most one in_progress item. This list does not require approval, create a durable goal, or trigger continued execution. Use updateTaskList for an existing unfinished list.',
      _ =>
        'Keep the existing task list current while work proceeds. Mark finished items completed before advancing the next item to in_progress, preserve completed work, and revise pending items when the approach changes. Do not create a list through updateTaskList. At most one item can be in_progress. A task list can exist without a goal and does not trigger continued execution. An empty list clears it.',
    },
    inputSchema: {
      'type': 'object',
      'properties': {
        if (name == 'createGoal') ...{
          'objective': {'type': 'string', 'minLength': 1},
          'tokenBudget': {
            'type': 'integer',
            'minimum': 1,
            'description':
                'Optional total input plus output token budget. Omit by default for unlimited. Set only when the user explicitly requests a concrete token amount for this goal. Never estimate or choose a budget.',
          },
        },
        if (name == 'updateGoal') ...{
          'status': {
            'type': 'string',
            'enum': ['active', 'complete', 'blocked', 'paused'],
          },
          'reason': {'type': 'string', 'minLength': 1},
          'blocker': {
            'type': 'string',
            'description':
                'Stable condition key, required when reporting blocked. Reuse it only while the same condition prevents progress.',
          },
        },
        if (name == 'createTaskList' || name == 'updateTaskList') ...{
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
        'createGoal' => ['objective'],
        'updateGoal' => ['status', 'reason'],
        'createTaskList' || 'updateTaskList' => ['explanation', 'steps'],
        _ => <String>[],
      },
      'additionalProperties': false,
    },
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    final args = call.arguments;
    final state = name == 'getGoal' || name == 'getTaskList'
        ? await store.read()
        : await store.change((state) {
            if (name == 'createGoal') {
              if (state['objective'] != null && state['status'] != 'complete') {
                throw StateError('已有未结束的目标，请先完成或取消');
              }
              state.removeWhere(
                (key, _) => key != 'steps' && key != 'explanation',
              );
              if (args['tokenBudget'] != null &&
                  (args['tokenBudget'] as int) <= 0)
                throw ArgumentError('Token 预算必须大于 0');
              state.addAll({
                'objective': args['objective'],
                'status': 'active',
                'turns': 0,
                'elapsedMs': 0,
                'tokensUsed': 0,
                if (args['tokenBudget'] != null)
                  'tokenBudget': args['tokenBudget'],
                'runningSince': DateTime.now().millisecondsSinceEpoch,
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
              ].contains(status)) {
                throw ArgumentError('目标状态无效');
              }
              if (status == 'active') {
                if (state['status'] == 'complete') {
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
              state['status'] = status;
              state['reason'] = args['reason'];
            } else {
              if (name == 'createTaskList' &&
                  (state['steps'] as List? ?? const []).any(
                    (s) => s['status'] != 'completed',
                  )) {
                throw StateError('已有未完成的任务清单，请使用 updateTaskList');
              }
              if (name == 'updateTaskList' && !state.containsKey('steps')) {
                throw StateError('当前没有任务清单，请先使用 createTaskList');
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
                throw ArgumentError('任务清单最多 30 项，同时只能有一项进行中');
              }
              state['steps'] = steps;
              state['explanation'] = args['explanation'];
            }
          });
    final isTaskList = name.endsWith('TaskList');
    final result = Map<String, dynamic>.from(state)
      ..removeWhere(
        (key, _) => isTaskList
            ? key != 'steps' && key != 'explanation'
            : key == 'steps' || key == 'explanation',
      );
    return ToolResult(
      callId: call.id,
      toolName: name,
      status: ToolResultStatus.success,
      output: {'task': result, 'kind': isTaskList ? 'taskList' : 'goal'},
    );
  }

  @override
  Future<void> cancel() async {}
}
