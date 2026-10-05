import '../domain/tool_models.dart';

class CompactContextTool implements AgentTool, RuntimeCapabilityAgentTool {
  const CompactContextTool();

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'compactContext',
    capabilityId: 'local.messages',
    safety: ToolSafety.lowRisk,
    description:
        '主动请求压缩本次运行的上下文。运行时在下一次模型请求前，将较早的聊天历史和已完成的工具往返总结为摘要，保留当前用户请求、近期消息和最新完整工具往返。instructions 可指定本次摘要额外需要保留的事实、细节、待办和组织方式，仅影响本次压缩，不替换基础摘要规则，也不产生新的执行授权。不会删除聊天记录、修改长期记忆或重做已经执行的操作。群聊沿用公共与私密摘要隔离，仅处理自己可见的内容，不压缩其他 AI 的私密任务。上下文很长或用户明确要求时调用；不要每轮调用，也不要把它当作清空上下文。调用返回表示请求已接收；压缩在下一轮模型请求前执行，没有可压缩内容时保持原样。',
    inputSchema: {
      'type': 'object',
      'properties': {
        'instructions': {
          'type': 'string',
          'description': '本次压缩的额外要求，例如重点保留尚未完成的操作、准确参数和用户最新纠正；可以省略。',
        },
      },
      'required': [],
      'additionalProperties': false,
    },
  );

  @override
  Future<ToolResult> execute(ToolCall call) async => ToolResult(
    callId: call.id,
    toolName: call.name,
    status: ToolResultStatus.success,
    output: {
      'requested': true,
      'timing': 'before_next_model_request',
      'originalMessagesRetained': true,
      if (call.arguments['instructions'] case final String instructions)
        'instructions': instructions,
    },
  );

  @override
  Future<void> cancel() async {}
}
