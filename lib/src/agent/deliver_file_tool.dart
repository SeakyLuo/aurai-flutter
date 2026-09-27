import '../domain/tool_models.dart';

class DeliverFileTool implements AgentTool, RuntimeCapabilityAgentTool {
  DeliverFileTool(this.send);

  bool _cancelled = false;
  final Future<Map<String, Object?>> Function(
    Map<String, Object?> arguments,
    bool Function() cancelled,
  )
  send;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'deliverFile',
    description:
        '将已生成的文件作为附件发送到当前会话。先用 executeAndroidScript 的 workspace 写入文件；'
        '支持任意文件类型，每个文件最多 100 MB。path 使用生成函数返回的绝对路径或工作目录内的相对路径，'
        'name 是用户看到的完整文件名（含正确扩展名），caption 是简短说明，可为空。'
        '发送的是独立副本，后续修改工作文件不改变历史附件。成功后附件卡片已经显示，'
        '不要重复发送，也不要把文件内容或 Base64 放进文字回复。仅能发送当前会话工作目录中的文件。',
    inputSchema: {
      'type': 'object',
      'properties': {
        'path': {'type': 'string', 'minLength': 1},
        'name': {'type': 'string', 'minLength': 1, 'maxLength': 120},
        'caption': {'type': 'string', 'maxLength': 2000},
      },
      'required': ['path', 'name', 'caption'],
      'additionalProperties': false,
    },
    safety: ToolSafety.lowRisk,
    capabilityId: 'local.attachments',
    executionTimeout: Duration(seconds: 60),
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    _cancelled = false;
    final output = await send(call.arguments, () => _cancelled);
    return ToolResult(
      callId: call.id,
      toolName: call.name,
      status: ToolResultStatus.success,
      output: output,
    );
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
  }
}
