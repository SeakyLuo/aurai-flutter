import '../domain/tool_models.dart';

class ChatRestTool implements AgentTool, RuntimeCapabilityAgentTool {
  ChatRestTool(this.name, this.change);

  static const names = ['sleepChat', 'pauseAutoReply', 'resumeAutoReply'];
  final String name;
  final Future<Map<String, Object?>> Function(
    String operation,
    Map<String, Object?> arguments,
  )
  change;

  @override
  ToolDefinition get definition => ToolDefinition(
    name: name,
    capabilityId: 'task.manage',
    description: switch (name) {
      'sleepChat' =>
        '在当前私聊或任务中让自己睡眠，结束本次执行，到时间后读取最新上下文再决定是否继续。所有模式都可用，无需创建目标或定时任务。seconds=-1 表示等待新消息，0 表示立即重新思考，正数表示休息秒数。用户发来新消息会提前唤醒。睡眠和私人草稿会持久保存，重启后恢复；用户停止执行会取消唤醒。draft 是留给自己的未发送提醒，不要自动发送；reason 说明为何等待以及醒来后检查什么。最后调用此工具，本轮不再调用其他工具。',
      'pauseAutoReply' =>
        '暂停自己在当前私聊或任务中的自动接话，结束本次执行并取消定时唤醒。所有模式都可用。暂停期间不自动处理交互回调；用户主动发来新消息或继续执行会恢复接话。保留目标和上下文。最后调用此工具，本轮不再调用其他工具。reason 说明暂停原因。',
      _ => '恢复自己在当前私聊或任务中的自动接话，继续响应后续交互回调。所有模式都可用。不创建新任务，不清除原有目标。',
    },
    safety: ToolSafety.lowRisk,
    inputSchema: {
      'type': 'object',
      'properties': {
        if (name != 'resumeAutoReply')
          'reason': {'type': 'string', 'minLength': 1},
        if (name == 'sleepChat') ...{
          'seconds': {'type': 'integer', 'minimum': -1},
          'draft': {'type': 'string'},
        },
      },
      'required': [
        if (name != 'resumeAutoReply') 'reason',
        if (name == 'sleepChat') ...['seconds', 'draft'],
      ],
      'additionalProperties': false,
    },
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    if (name != 'resumeAutoReply') {
      final reason = call.arguments['reason'];
      if (reason is! String || reason.trim().isEmpty) {
        throw ArgumentError('请填写睡眠或暂停原因');
      }
    }
    if (name == 'sleepChat') {
      final seconds = call.arguments['seconds'];
      if (seconds is! int || seconds < -1) {
        throw ArgumentError('睡眠时间必须为 -1 或非负整数秒');
      }
      if (call.arguments['draft'] is! String) {
        throw ArgumentError('私人草稿必须为文本');
      }
    }
    return ToolResult(
      callId: call.id,
      toolName: name,
      status: ToolResultStatus.success,
      output: await change(name, call.arguments),
    );
  }

  @override
  Future<void> cancel() async {}
}
