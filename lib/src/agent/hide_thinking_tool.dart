import '../domain/tool_models.dart';

class HideThinkingTool implements AgentTool, RuntimeCapabilityAgentTool {
  HideThinkingTool(this.hide);
  final Map<String, Object?> Function(Set<String>, Set<String>, bool) hide;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'hideThinking',
    capabilityId: 'local.messages',
    safety: ToolSafety.lowRisk,
    description:
        '隐藏指定 AI 成员本次任务后续的可见思考；界面仍显示正在思考。senderIds 为空且 all=false 时仅隐藏自己；all=true 时隐藏当前群全部有可见思考的 AI，excludeSenderIds 排除指定成员。使用当前群成员列表中的 senderId，不让用户填写。仅处理确实需要保密的内容时调用，普通聊天不需要调用；没有可见思考的成员不需要隐藏。群聊内对选定成员的隐藏持续到本轮群任务结束，也覆盖该成员后续接话。多次调用只增加隐藏对象，排除仅作用于本次新增范围，不会重新公开已经隐藏的思考。不会隐藏正式消息、改变工具权限或撤回已经展示的思考。'
        '如果目标模型没有向界面展示思考过程（例如当前 ChatGPT/OpenAI 通道），或已关闭思考，就不要调用本工具；模型内部思考不等于界面有可见思考。不要将隐藏思考作为每次回复或使用工具前的固定步骤。',
    inputSchema: {
      'type': 'object',
      'properties': {
        'senderIds': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': '要隐藏的 AI 成员；空数组表示自己，all=true 时忽略此数组',
        },
        'excludeSenderIds': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': '本次新增隐藏范围中排除的 AI 成员，排除优先',
        },
        'all': {'type': 'boolean', 'description': '是否选择当前群全部 AI 成员'},
      },
      'required': ['senderIds', 'excludeSenderIds', 'all'],
      'additionalProperties': false,
    },
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    final result = hide(
      (call.arguments['senderIds'] as List).cast<String>().toSet(),
      (call.arguments['excludeSenderIds'] as List).cast<String>().toSet(),
      call.arguments['all'] as bool,
    );
    return ToolResult(
      callId: call.id,
      toolName: call.name,
      status: ToolResultStatus.success,
      output: result,
    );
  }

  @override
  Future<void> cancel() async {}
}
