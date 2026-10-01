import '../domain/tool_models.dart';

class GroupAutoReplyTool implements AgentTool, RuntimeCapabilityAgentTool {
  GroupAutoReplyTool({
    required this.pause,
    required this.change,
    this.currentGroupId,
  });
  final bool pause;
  final String? currentGroupId;
  final Future<void> Function(
    String groupId,
    String senderId,
    bool triggerReply,
  )
  change;

  @override
  ToolDefinition get definition => ToolDefinition(
    name: pause ? 'pauseGroupAutoReply' : 'resumeGroupAutoReply',
    description:
        '${pause ? '暂停指定群聊中指定 AI 成员的自动接话，并停止其当前执行及定时唤醒。' : '恢复指定群聊中指定 AI 成员的自动接话。triggerReply 默认 false；为 true 时立即安排该成员读取最新群聊并思考一次，不保证实际发言。恢复后会响应后续普通群消息，不是单次发言许可。'} '
        '可在任何会话中调用；没有当前群时必须提供 groupId。只能调整已加入群中的 AI 成员；调整自己无需授权，调整其他 AI 必须通过工具申请用户授权，授权仅限指定目标和操作。遵守用户明确的暂停或发言安排。通过 readGroupChat 获取 groupId 和 senderId，不让用户填写。轮流发言时，先暂停上一位，再恢复下一位并触发回复。不要在已成功触发后重复调用。',
    capabilityId: 'local.group_chats',
    safety: ToolSafety.lowRisk,
    inputSchema: {
      'type': 'object',
      'properties': {
        'groupId': {
          'type': ['string', 'null'],
          'description': '目标群聊；私聊必填，群聊省略或 null 表示当前群',
        },
        'senderId': {'type': 'string', 'description': '目标群聊中的 AI 成员'},
        if (!pause)
          'triggerReply': {
            'type': 'boolean',
            'default': false,
            'description': '是否立即触发一次思考；false 仅恢复自动接话',
          },
      },
      'required': ['senderId', if (currentGroupId == null) 'groupId'],
      'additionalProperties': false,
    },
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    final trigger =
        !pause && (call.arguments['triggerReply'] as bool? ?? false);
    final sender = call.arguments['senderId'] as String;
    final groupId = call.arguments['groupId'] as String? ?? currentGroupId;
    if (groupId == null) throw ArgumentError('私聊调用必须指定目标群聊 groupId');
    await change(groupId, sender, trigger);
    return ToolResult(
      callId: call.id,
      toolName: call.name,
      status: ToolResultStatus.success,
      output: {
        'groupId': groupId,
        'senderId': sender,
        'paused': pause,
        'replyRequested': trigger,
      },
    );
  }

  @override
  Future<void> cancel() async {}
}
