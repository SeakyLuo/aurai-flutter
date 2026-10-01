import '../domain/tool_models.dart';

class GroupAutoReplyTool implements AgentTool, RuntimeCapabilityAgentTool {
  GroupAutoReplyTool({required this.pause, required this.change});
  final bool pause;
  final Future<void> Function(String senderId, bool triggerReply) change;

  @override
  ToolDefinition get definition => ToolDefinition(
    name: pause ? 'pauseGroupAutoReply' : 'resumeGroupAutoReply',
    description:
        '${pause ? '暂停当前群聊中指定 AI 成员的自动接话，并停止其当前执行及定时唤醒。' : '恢复当前群聊中指定 AI 成员的自动接话。triggerReply 默认 false；为 true 时立即安排该成员读取最新群聊并思考一次，不保证实际发言。恢复后会响应后续普通群消息，不是单次发言许可。'} '
        '同群内可根据对话和轮流发言需要直接调用，无需另行请求用户授权；遵守用户明确的暂停或发言安排。使用群成员列表的 senderId，不让用户填写。只能操作当前群聊中的其他 AI 成员，不支持跨群。轮流发言时，先暂停上一位，再恢复下一位并触发回复。不要在已成功触发后重复调用。',
    capabilityId: 'local.group_chats',
    safety: ToolSafety.lowRisk,
    inputSchema: {
      'type': 'object',
      'properties': {
        'senderId': {'type': 'string', 'description': '当前群聊中的目标 AI 成员'},
        if (!pause)
          'triggerReply': {
            'type': 'boolean',
            'default': false,
            'description': '是否立即触发一次思考；false 仅恢复自动接话',
          },
      },
      'required': ['senderId'],
      'additionalProperties': false,
    },
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    final trigger =
        !pause && (call.arguments['triggerReply'] as bool? ?? false);
    final sender = call.arguments['senderId'] as String;
    await change(sender, trigger);
    return ToolResult(
      callId: call.id,
      toolName: call.name,
      status: ToolResultStatus.success,
      output: {'senderId': sender, 'paused': pause, 'replyRequested': trigger},
    );
  }

  @override
  Future<void> cancel() async {}
}
