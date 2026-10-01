import '../domain/tool_models.dart';
import '../domain/group_mute.dart';

class GroupMuteTool implements AgentTool, RuntimeCapabilityAgentTool {
  GroupMuteTool(this.change, {this.currentGroupId});
  final String? currentGroupId;
  final Future<void> Function(
    String groupId,
    String senderId,
    Duration? duration,
  )
  change;
  @override
  ToolDefinition get definition => ToolDefinition(
    name: 'setGroupMemberMute',
    capabilityId: 'local.group_chats',
    safety: ToolSafety.lowRisk,
    description:
        '设置目标群成员禁言或解除禁言。可从任何会话调用；省略 groupId 使用当前群，没有当前群时必须指定目标群。只有目标群的群主和管理员可调用；群主可管理管理员和普通成员，管理员只可管理普通成员，不能管理自己或群主。适用于真人和 AI。禁言强制阻止发消息，@、自动接话及定时唤醒都不能绕过。durationMinutes 为 null 永久禁言，为 0 解除禁言，正数按分钟设置限时禁言，最长 30 天，到期自动解除。不改变自动接话设置。根据用户明确安排或正在主持的游戏规则操作；通过 readGroupChat 获取目标群和成员，不让用户填写 ID。',
    inputSchema: {
      'type': 'object',
      'properties': {
        'groupId': {
          'type': ['string', 'null'],
        },
        'senderId': {'type': 'string'},
        'durationMinutes': {
          'type': ['integer', 'null'],
          'minimum': 0,
          'maximum': GroupMute.maxDuration.inMinutes,
        },
      },
      'required': [
        'senderId',
        'durationMinutes',
        if (currentGroupId == null) 'groupId',
      ],
      'additionalProperties': false,
    },
  );
  @override
  Future<ToolResult> execute(ToolCall call) async {
    final minutes = call.arguments['durationMinutes'] as int?;
    final groupId = call.arguments['groupId'] as String? ?? currentGroupId;
    if (groupId == null) throw ArgumentError('请指定目标群聊 groupId');
    await change(
      groupId,
      call.arguments['senderId'] as String,
      minutes == null ? null : Duration(minutes: minutes),
    );
    return ToolResult(
      callId: call.id,
      toolName: call.name,
      status: ToolResultStatus.success,
      output: {
        'groupId': groupId,
        'muted': minutes != 0,
        'durationMinutes': minutes,
      },
    );
  }

  @override
  Future<void> cancel() async {}
}
