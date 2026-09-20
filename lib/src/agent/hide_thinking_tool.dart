import '../domain/tool_models.dart';

class HideThinkingTool implements AgentTool, RuntimeCapabilityAgentTool {
  HideThinkingTool(this.hide);
  final void Function() hide;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'hideThinking',
    capabilityId: 'local.messages',
    safety: ToolSafety.lowRisk,
    description:
        '隐藏本次任务后续的思考内容，直到任务结束；界面仍显示正在思考。处理秘密词语、身份、匿名内容等信息前先调用。不会隐藏正式消息或改变工具权限，也不能撤回已经展示的思考。',
    inputSchema: {
      'type': 'object',
      'properties': {},
      'additionalProperties': false,
    },
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    hide();
    return ToolResult(
      callId: call.id,
      toolName: call.name,
      status: ToolResultStatus.success,
      output: {'hidden': true, 'scope': 'current_task'},
    );
  }

  @override
  Future<void> cancel() async {}
}
