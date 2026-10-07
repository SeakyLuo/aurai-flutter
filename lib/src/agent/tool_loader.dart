import '../domain/tool_models.dart';
import 'tool_registry.dart';

class ToolLoader implements AgentTool, RuntimeCapabilityAgentTool {
  ToolLoader(this.registry);
  final ToolRegistry registry;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'loadTools',
    description:
        'Load full tool descriptions and schemas for the next model turn. Use exact names from searchTools. Select only tools needed now, at most five. Loading does not execute tools or grant permission.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'names': {
          'type': 'array',
          'minItems': 1,
          'maxItems': 5,
          'uniqueItems': true,
          'items': {'type': 'string', 'minLength': 1},
        },
      },
      'required': ['names'],
      'additionalProperties': false,
    },
    safety: ToolSafety.readOnly,
    capabilityId: 'runtime.tool_search',
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    final names = (call.arguments['names'] as List).cast<String>();
    final available = registry.catalog.map((tool) => tool.name).toSet();
    final missing = names.where((name) => !available.contains(name)).toList();
    if (names.isEmpty ||
        names.length > 5 ||
        names.toSet().length != names.length ||
        missing.isNotEmpty) {
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.error,
        output: {
          'error': 'Select 1–5 distinct available tool names from searchTools.',
          'unavailable': missing,
        },
      );
    }
    registry.load(names.reversed);
    return ToolResult(
      callId: call.id,
      toolName: call.name,
      status: ToolResultStatus.success,
      output: {
        'loaded': names,
        'message':
            'Use the full definitions supplied on the next turn. Loading grants no permission.',
      },
    );
  }

  @override
  Future<void> cancel() async {}
}
