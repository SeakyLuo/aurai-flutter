import '../domain/tool_models.dart';

class GroupWakeTool implements AgentTool, RuntimeCapabilityAgentTool {
  GroupWakeTool(this.wake);
  final Future<bool> Function(String senderId) wake;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'wakeGroupMember',
    description:
        '唤醒当前群聊中正在定时睡眠的另一位 AI 成员。群里会记录“你唤醒了该成员”的系统事件，目标会带着最新消息重新思考。使用群成员列表中的 senderId，不要让用户填写。仅在需要对方参与或用户要求时调用，不要为了维持闲聊反复互相唤醒。不解除暂停自动接话，也不保证对方发言；已醒的成员不会重复触发。',
    capabilityId: 'local.group_chats',
    safety: ToolSafety.lowRisk,
    inputSchema: {
      'type': 'object',
      'properties': {
        'senderId': {'type': 'string', 'description': '当前群聊中要唤醒的 AI 成员'},
      },
      'required': ['senderId'],
      'additionalProperties': false,
    },
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    try {
      final woke = await wake(call.arguments['senderId'] as String);
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.success,
        output: {'wakeRequested': woke, if (!woke) 'reason': '该成员当前没有定时睡眠'},
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

  @override
  Future<void> cancel() async {}
}
