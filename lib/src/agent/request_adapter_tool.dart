import '../domain/tool_models.dart';

class RequestAdapterTool implements AgentTool, RuntimeCapabilityAgentTool {
  RequestAdapterTool(this.name, this.invoke);
  final String name;
  final Future<Map<String, Object?>> Function(String, Map<String, Object?>)
  invoke;
  static const names = [
    'readRequestAdapters',
    'previewRequestAdapter',
    'saveRequestAdapter',
  ];
  @override
  ToolDefinition get definition => ToolDefinition(
    name: name,
    capabilityId: 'model.settings',
    safety: name == 'saveRequestAdapter'
        ? ToolSafety.lowRisk
        : ToolSafety.readOnly,
    description:
        'Manage custom request adapters when requested. Read current scripts first. provider comes from readDefaultModels. model is an exact model name, or empty string for provider default. Model overrides replace the provider adapter. protocol=null follows provider, otherwise openaiChatCompletions or responses selects BOTH request encoder and response decoder. script is a JavaScript function body receiving request={model,path,body}; return {path,body}. Runs locally without credentials, network, files or Java access. Use ES6 syntax. Do not change stream. Changing a path alone does not change the response protocol. preview executes a synthetic local request, NOT a network compatibility test. save validates locally before persisting; do not claim live compatibility without a successful actual request. Empty script and null protocol removes the override. Preserve unrelated settings. Example parameter rename: request.body.max_completion_tokens=request.body.max_tokens; delete request.body.max_tokens; return request;',
    inputSchema: {
      'type': 'object',
      'properties': {
        'provider': {'type': 'string'},
        if (name != 'readRequestAdapters') ...{
          'model': {'type': 'string'},
          'protocol': {
            'type': ['string', 'null'],
            'enum': [null, 'openaiChatCompletions', 'responses'],
          },
          'script': {'type': 'string'},
        },
      },
      'required': [
        'provider',
        if (name != 'readRequestAdapters') ...['model', 'protocol', 'script'],
      ],
      'additionalProperties': false,
    },
  );
  @override
  Future<ToolResult> execute(ToolCall call) async {
    try {
      return ToolResult(
        callId: call.id,
        toolName: name,
        status: ToolResultStatus.success,
        output: await invoke(name, call.arguments),
      );
    } on Object catch (error) {
      return ToolResult(
        callId: call.id,
        toolName: name,
        status: ToolResultStatus.error,
        output: {'message': error.toString()},
      );
    }
  }

  @override
  Future<void> cancel() async {}
}
