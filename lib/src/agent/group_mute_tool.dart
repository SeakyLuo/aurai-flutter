import '../domain/tool_models.dart';

class GroupMuteTool implements AgentTool, RuntimeCapabilityAgentTool {
  GroupMuteTool(this.change);
  final Future<void> Function(String senderId, Duration? duration) change;
  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'setGroupMemberMute',
    capabilityId: 'local.group_chats',
    safety: ToolSafety.lowRisk,
    description:
        '设置当前群成员禁言或解除禁言。只有群主和管理员可调用；群主可管理管理员和普通成员，管理员只可管理普通成员，不能管理自己或群主。适用于真人和 AI。禁言强制阻止发消息，@、自动接话及定时唤醒都不能绕过。durationMinutes 为 null 永久禁言，为 0 解除禁言，正数按分钟设置限时禁言，到期自动解除。不改变自动接话设置。根据用户明确安排或正在主持的游戏规则操作；从群成员列表选 senderId，不让用户填写。',
    inputSchema: {
      'type': 'object',
      'properties': {
        'senderId': {'type': 'string'},
        'durationMinutes': {
          'type': ['integer', 'null'],
          'minimum': 0,
        },
      },
      'required': ['senderId', 'durationMinutes'],
      'additionalProperties': false,
    },
  );
  @override
  Future<ToolResult> execute(ToolCall call) async {
    final minutes = call.arguments['durationMinutes'] as int?;
    await change(
      call.arguments['senderId'] as String,
      minutes == null ? null : Duration(minutes: minutes),
    );
    return ToolResult(
      callId: call.id,
      toolName: call.name,
      status: ToolResultStatus.success,
      output: {'muted': minutes != 0, 'durationMinutes': minutes},
    );
  }

  @override
  Future<void> cancel() async {}
}
