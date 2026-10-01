import '../domain/tool_models.dart';

class GroupWakeTool implements AgentTool, RuntimeCapabilityAgentTool {
  GroupWakeTool(this.wake, {this.currentGroupId});
  final String? currentGroupId;
  final Future<bool> Function(String groupId, String senderId) wake;

  @override
  ToolDefinition get definition => ToolDefinition(
    name: 'wakeGroupMember',
    description:
        '唤醒你已加入的目标群聊中正在定时睡眠的 AI 成员。可直接调用，无需申请授权；只能唤醒未暂停自动接话、未禁言且确实正在睡眠的成员，不保证对方发言，已醒的成员不会重复触发。可从任何会话调用；省略 groupId 使用当前群，没有当前群时必须指定目标群。群里记录真实操作者和目标的姓名。使用 readGroupChat 返回的 groupId 和 senderId，不要让用户填写。仅在需要对方参与或用户要求时调用，不要为了维持闲聊反复互相唤醒。',
    capabilityId: 'local.group_chats',
    safety: ToolSafety.lowRisk,
    inputSchema: {
      'type': 'object',
      'properties': {
        'groupId': {
          'type': ['string', 'null'],
        },
        'senderId': {'type': 'string', 'description': '当前群聊中要唤醒的 AI 成员'},
      },
      'required': ['senderId', if (currentGroupId == null) 'groupId'],
      'additionalProperties': false,
    },
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    final groupId = call.arguments['groupId'] as String? ?? currentGroupId;
    if (groupId == null) throw ArgumentError('请指定目标群聊 groupId');
    final woke = await wake(groupId, call.arguments['senderId'] as String);
    return ToolResult(
      callId: call.id,
      toolName: call.name,
      status: ToolResultStatus.success,
      output: {
        'groupId': groupId,
        'wakeRequested': woke,
        if (!woke) 'reason': '该成员当前没有定时睡眠',
      },
    );
  }

  @override
  Future<void> cancel() async {}
}
