import '../domain/tool_models.dart';

/// A program-owned decision request, separate from ordinary assistant replies.
class ResponseDecision implements AgentTool, RuntimeCapabilityAgentTool {
  static final catalog = [
    ToolDefinition(
      name: 'submitInteractiveChoice',
      capabilityId: 'interactiveDecision',
      safety: ToolSafety.lowRisk,
      description: '为当前交互卡片提交一个选项。仅在程序发起单选行动时可用，提交成功后结束本轮。',
      inputSchema: const {
        'type': 'object',
        'properties': {
          'choice': {'type': 'integer', 'minimum': 1},
        },
        'required': ['choice'],
        'additionalProperties': false,
      },
    ),
    ToolDefinition(
      name: 'finishCurrentAction',
      capabilityId: 'interactiveDecision',
      safety: ToolSafety.lowRisk,
      description: '完成行动后提交当前行动卡。仅在程序提供无需额外输入的提交操作时可用，由程序继续流程。',
      inputSchema: const {
        'type': 'object',
        'properties': <String, Object?>{},
        'required': <String>[],
        'additionalProperties': false,
      },
    ),
  ];
  const ResponseDecision({
    required this.instructions,
    required this.schema,
    required this.submit,
    this.name = 'submitInteractiveChoice',
    this.description = '为当前交互卡片提交一个选项。提交成功后结束本轮。',
    this.exclusive = true,
  });

  final String instructions;
  final String name, description;
  final bool exclusive;
  final Map<String, Object?> schema;
  final Future<void> Function(Map<String, Object?> arguments) submit;

  @override
  ToolDefinition get definition => ToolDefinition(
    name: name,
    description: description,
    inputSchema: schema,
    safety: ToolSafety.lowRisk,
    capabilityId: 'interactiveDecision',
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    await submit(call.arguments);
    return ToolResult(
      callId: call.id,
      toolName: call.name,
      status: ToolResultStatus.success,
      output: const {'submitted': true},
    );
  }

  @override
  Future<void> cancel() async {}
}
