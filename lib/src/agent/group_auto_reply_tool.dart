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
    Set<String> senderIds,
    bool all,
    bool triggerReply,
  )
  change;

  @override
  ToolDefinition get definition => ToolDefinition(
    name: pause ? 'pauseGroupAutoReply' : 'resumeGroupAutoReply',
    description:
        '${pause ? '暂停指定群聊中指定 AI 成员的自动接话，并停止其当前执行及定时唤醒。' : '恢复指定群聊中指定 AI 成员的自动接话。triggerReply 默认 false；为 true 时立即安排该成员读取最新群聊并思考一次，不保证实际发言。恢复后会响应后续普通群消息，不是单次发言许可。'} '
        '可在任何会话中调用；没有当前群时必须提供 groupId。只能调整已加入群中的 AI 成员。调整自己无需授权；群主可直接调整其他成员，管理员可直接调整普通成员和其他管理员，无需审批；普通成员调整其他普通成员须通过工具申请用户授权。不能调整更高角色成员，也不能申请越权。授权限定调用 AI、目标群、目标成员及暂停或恢复操作；triggerReply 不改变恢复授权范围。遵守用户明确的暂停或发言安排。senderId、senderIds、all 三选一；senderIds/all 批量操作仅限群主或群管理员，普通成员不能申请越权。批量操作会先校验所有目标权限，不能调整的成员会导致整批拒绝。通过 readGroupChat 获取 groupId 和 senderId，不让用户填写。轮流发言时，先暂停上一位，再恢复下一位并触发回复。不要在已成功触发后重复调用。',
    capabilityId: 'local.group_chats',
    safety: ToolSafety.lowRisk,
    inputSchema: {
      'type': 'object',
      'properties': {
        'groupId': {
          'type': ['string', 'null'],
          'description': '目标群聊；私聊必填，群聊省略或 null 表示当前群',
        },
        'senderId': {
          'type': 'string',
          'description': '单个目标，与 senderIds/all 三选一',
        },
        'senderIds': {
          'type': 'array',
          'minItems': 1,
          'uniqueItems': true,
          'items': {'type': 'string'},
          'description': '一批目标 AI 成员；统一校验权限后批量保存',
        },
        'all': {'type': 'boolean', 'description': 'true 表示群内全部 AI；权限不因批量操作而扩大'},
        if (!pause)
          'triggerReply': {
            'type': 'boolean',
            'default': false,
            'description': '是否立即触发一次思考；false 仅恢复自动接话',
          },
      },
      'required': [if (currentGroupId == null) 'groupId'],
      'additionalProperties': false,
    },
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    final trigger =
        !pause && (call.arguments['triggerReply'] as bool? ?? false);
    final args = call.arguments;
    if ([
          args['senderId'] != null,
          args['senderIds'] != null,
          args['all'] == true,
        ].where((v) => v).length !=
        1)
      throw ArgumentError('senderId、senderIds、all 必须三选一');
    final senders = {
      if (args['senderId'] != null) args['senderId'] as String,
      ...?(args['senderIds'] as List?)?.cast<String>(),
    };
    final groupId = call.arguments['groupId'] as String? ?? currentGroupId;
    if (groupId == null) throw ArgumentError('私聊调用必须指定目标群聊 groupId');
    await change(groupId, senders, args['all'] == true, trigger);
    return ToolResult(
      callId: call.id,
      toolName: call.name,
      status: ToolResultStatus.success,
      output: {
        'groupId': groupId,
        'senderIds': senders.toList(),
        'all': args['all'] == true,
        'paused': pause,
        'replyRequested': trigger,
      },
    );
  }

  @override
  Future<void> cancel() async {}
}
