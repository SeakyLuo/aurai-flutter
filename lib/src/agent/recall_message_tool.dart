import '../domain/tool_models.dart';

class RecallMessageTool implements AgentTool, RuntimeCapabilityAgentTool {
  RecallMessageTool(this.recall);

  final Future<void> Function(String messageId) recall;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'recallMessage',
    capabilityId: 'local.history',
    safety: ToolSafety.lowRisk,
    description:
        '撤回你自己在有权访问的私聊或群聊中已经发送的消息，无需切换会话。'
        '从当前消息上下文或 searchMessages 获取消息 ID，不要让用户填写 ID。'
        '不能撤回用户、其他 AI 或系统消息。撤回提示沿用原消息的可见范围，原本无权查看的人看不到撤回事件；引用内容变为消息已撤回。'
        '这不会撤销消息中提及的实际操作，也无法让其他成员忘记已经读到的内容。',
    inputSchema: {
      'type': 'object',
      'properties': {
        'messageId': {'type': 'string', 'description': '要撤回的已发送消息 ID'},
      },
      'required': ['messageId'],
      'additionalProperties': false,
    },
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    try {
      await recall(call.arguments['messageId'] as String);
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.success,
        output: const {'recalled': true},
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
