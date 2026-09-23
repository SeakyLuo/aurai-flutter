import '../domain/model_provider.dart';
import '../domain/image_generation_config.dart';
import '../domain/tool_models.dart';

class DefaultModelTool implements AgentTool, RuntimeCapabilityAgentTool {
  DefaultModelTool({
    required this.update,
    required this.settings,
    required this.imageGeneration,
    required this.save,
  });
  final ImageGenerationConfig? Function() imageGeneration;
  final bool update;
  final ModelSettings Function() settings;
  final Future<void> Function(ModelPurpose, DefaultModelSelection) save;

  @override
  ToolDefinition get definition => ToolDefinition(
    name: update ? 'updateDefaultModel' : 'readDefaultModels',
    capabilityId: 'model.settings',
    safety: update ? ToolSafety.lowRisk : ToolSafety.readOnly,
    description: update
        ? 'Change one app-wide default model when requested by the user: text, imageUnderstanding, imageGeneration, videoUnderstanding or videoGeneration. Read readDefaultModels first to discover saved providers and models. Use an exact model ID suitable for the requested purpose; savedModels are suggestions, not an allowlist. Other defaults and per-AI model selections are preserved. Provider credentials and URL come from saved settings. Applies to subsequent calls, not the already running request.'
        : 'Read app-wide default models for text, image understanding/generation and video understanding/generation, plus saved providers and model IDs. Does not expose credentials. A null default means that purpose has no configured model. Use updateDefaultModel for app defaults, updateAiContact for an individual AI model.',
    inputSchema: {
      'type': 'object',
      'properties': {
        if (update) ...{
          'purpose': {
            'type': 'string',
            'enum': ModelPurpose.values.map((p) => p.name).toList(),
          },
          'provider': {
            'type': 'string',
            'description': 'Provider identifier returned by readDefaultModels.',
          },
          'model': {'type': 'string', 'minLength': 1},
        },
      },
      'required': update ? ['purpose', 'provider', 'model'] : <String>[],
      'additionalProperties': false,
    },
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    try {
      final Map<String, Object?> output;
      if (update) {
        final purpose = ModelPurpose.values.byName(
          call.arguments['purpose'] as String,
        );
        final provider = ModelService.byName(
          call.arguments['provider'] as String,
        );
        if (!settings().profiles.containsKey(provider))
          throw ArgumentError('供应商不存在');
        final model = (call.arguments['model'] as String).trim();
        if (model.isEmpty) throw ArgumentError('模型名称不能为空');
        await save(
          purpose,
          DefaultModelSelection(service: provider, model: model, name: model),
        );
        output = {
          'saved': true,
          'purpose': purpose.name,
          'provider': provider.name,
          'model': model,
        };
      } else {
        final current = settings();
        output = {
          'defaults': {
            for (final purpose in ModelPurpose.values)
              purpose.name: purpose == ModelPurpose.imageGeneration
                  ? (imageGeneration() == null
                        ? null
                        : {
                            'provider': imageGeneration()!.service.name,
                            'model': imageGeneration()!.model.id,
                          })
                  : current.configFor(purpose) != null
                  ? {
                      'provider': current.configFor(purpose)!.service.name,
                      'model': current.configFor(purpose)!.model,
                    }
                  : purpose == ModelPurpose.text
                  ? {
                      'provider': current.activeConfig.service.name,
                      'model': current.activeConfig.model,
                    }
                  : null,
          },
          'providers': [
            for (final config in current.profiles.values)
              {
                'provider': config.service.name,
                'name': config.displayName,
                'configured': config.isConfigured,
                'savedModels': config.savedModels,
                'model': config.model,
              },
          ],
        };
      }
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.success,
        output: output,
      );
    } on Object catch (error) {
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.error,
        output: {'message': error.toString()},
      );
    }
  }

  @override
  Future<void> cancel() async {}
}
