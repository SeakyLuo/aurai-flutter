import '../domain/model_provider.dart';
import '../domain/tool_models.dart';
import '../providers/model_balance.dart';

class GetModelBalanceTool implements AgentTool, RuntimeCapabilityAgentTool {
  GetModelBalanceTool(this.settings);
  final ModelSettings settings;
  final _client = ModelBalanceClient();

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'getModelBalance',
    description:
        'Query the real remaining account balance using the saved provider credentials. Currently supports official DeepSeek accounts only; other providers and custom gateways return an explicit error. No API key is exposed to the model. Return currency, available total, remaining top-up funds, remaining grants, and observation time. Total already includes grants: do not add them again. Preserve currencies, never infer initial recharge, spending or future call counts from this snapshot. This is account-wide balance, not Aurai-only usage. Query fresh when asked.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'provider': {
          'type': 'string',
          'enum': ['current', 'deepSeek', 'openAi'],
          'description':
              'current uses the active provider; select deepSeek to query its saved account even when another model is active.',
        },
      },
      'required': ['provider'],
      'additionalProperties': false,
    },
    safety: ToolSafety.readOnly,
    capabilityId: 'model.balance',
    executionTimeout: Duration(seconds: 12),
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    final service = switch (call.arguments['provider'] as String) {
      'current' => settings.activeService,
      'deepSeek' => ModelService.deepSeek,
      'openAi' => ModelService.openAi,
      _ => throw const FormatException('Unknown model provider'),
    };
    try {
      final balance = await _client.load(settings.profile(service));
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.success,
        output: balance.toJson(),
      );
    } on ModelProviderException catch (error) {
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.error,
        output: {'provider': service.label, 'error': error.message},
      );
    }
  }

  @override
  Future<void> cancel() async => _client.close();
}
