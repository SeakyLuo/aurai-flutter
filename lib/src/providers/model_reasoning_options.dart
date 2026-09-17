import '../domain/model_provider.dart';
import 'openrouter_models.dart';

const _defaultOnly = [ModelReasoning.automatic];
const _toggle = [
  ModelReasoning.automatic,
  ModelReasoning.none,
  ModelReasoning.enabled,
];
const _standard = [
  ModelReasoning.automatic,
  ModelReasoning.low,
  ModelReasoning.medium,
  ModelReasoning.high,
];

List<ModelReasoning> providerReasoningOptions(ModelService service) =>
    switch (service) {
      ModelService.deepSeek => const [
        ModelReasoning.automatic,
        ModelReasoning.none,
        ModelReasoning.low,
        ModelReasoning.high,
        ModelReasoning.max,
      ],
      ModelService.openAi || ModelService.openRouter => const [
        ModelReasoning.automatic,
        ModelReasoning.none,
        ModelReasoning.minimal,
        ModelReasoning.low,
        ModelReasoning.medium,
        ModelReasoning.high,
        ModelReasoning.xhigh,
        ModelReasoning.max,
      ],
      ModelService.qwen || ModelService.kimi || ModelService.glm => _toggle,
    };

/// Offer only documented controls; leaving the preference at default sends no
/// extra parameter and preserves the provider's own behavior.
/// https://api-docs.deepseek.com/guides/thinking_mode/
/// https://developers.openai.com/api/docs/guides/reasoning
/// https://openrouter.ai/docs/guides/best-practices/reasoning-tokens
List<ModelReasoning> modelReasoningOptions(
  ModelService service,
  String model,
  String baseUrl,
) {
  switch (service) {
    case ModelService.deepSeek:
      return switch (model) {
        'deepseek-flash' ||
        'deepseek-v4.1-flash' ||
        'deepseek-v4-flash' ||
        'deepseek-v4-pro' ||
        'deepseek-v4-flash-vision-exp' => const [
          ModelReasoning.automatic,
          ModelReasoning.none,
          ModelReasoning.low,
          ModelReasoning.high,
          ModelReasoning.max,
        ],
        _ => _defaultOnly,
      };
    case ModelService.openAi:
      return _openAiOptions(model);
    case ModelService.openRouter:
      final info = OpenRouterModels.lookup(baseUrl, model);
      if (info == null ||
          !(info.supports('reasoning') || info.supports('reasoning_effort'))) {
        return _defaultOnly;
      }
      if (model.startsWith('openai/')) {
        return _openAiOptions(model.substring('openai/'.length));
      }
      return const [
        ModelReasoning.automatic,
        ModelReasoning.none,
        ModelReasoning.minimal,
        ModelReasoning.low,
        ModelReasoning.medium,
        ModelReasoning.high,
        ModelReasoning.xhigh,
      ];
    case ModelService.qwen:
      // https://help.aliyun.com/en/model-studio/deep-thinking
      return switch (model) {
        'qwen-plus' ||
        'qwen-plus-latest' ||
        'qwen-plus-2025-09-11' ||
        'qwen-flash' ||
        'qwen3-max' ||
        'qwen3-max-2026-01-23' => _toggle,
        _ => _defaultOnly,
      };
    case ModelService.kimi:
      // https://platform.kimi.com/docs/guide/use-thinking-models
      return switch (model) {
        'kimi-k2.5' || 'kimi-k2.6' => _toggle,
        _ => _defaultOnly,
      };
    case ModelService.glm:
      // https://docs.z.ai/guides/capabilities/thinking-mode
      return switch (model) {
        'glm-4.5' ||
        'glm-4.5-air' ||
        'glm-4.6' ||
        'glm-4.7' ||
        'glm-4.7-flash' ||
        'glm-4.7-flashx' ||
        'glm-5' ||
        'glm-5.1' ||
        'glm-5.2' => _toggle,
        _ => _defaultOnly,
      };
  }
}

List<ModelReasoning> _openAiOptions(String model) {
  if (model.startsWith('gpt-6-astra')) {
    return [..._standard, ModelReasoning.xhigh, ModelReasoning.max];
  }
  if (model.startsWith('gpt-5.6')) {
    return [
      ModelReasoning.automatic,
      ModelReasoning.none,
      ..._standard.skip(1),
      ModelReasoning.xhigh,
      ModelReasoning.max,
    ];
  }
  if (model.contains('chat') || model.contains('deep-research')) {
    return _defaultOnly;
  }
  if (model == 'gpt-5-pro' || model.startsWith('o3-pro')) {
    return const [ModelReasoning.automatic, ModelReasoning.high];
  }
  if (model.contains('-pro') && model.startsWith('gpt-5.')) {
    return const [
      ModelReasoning.automatic,
      ModelReasoning.medium,
      ModelReasoning.high,
      ModelReasoning.xhigh,
    ];
  }
  if (model.startsWith('gpt-5.2') ||
      model.startsWith('gpt-5.4') ||
      model.startsWith('gpt-5.5')) {
    return [
      ModelReasoning.automatic,
      if (!model.contains('codex')) ModelReasoning.none,
      ..._standard.skip(1),
      ModelReasoning.xhigh,
    ];
  }
  if (model.startsWith('gpt-5.1') && !model.contains('codex')) {
    return [
      ModelReasoning.automatic,
      ModelReasoning.none,
      ..._standard.skip(1),
    ];
  }
  if (model == 'gpt-5' ||
      model.startsWith('gpt-5-2025-') ||
      model.startsWith('gpt-5-mini') ||
      model.startsWith('gpt-5-nano')) {
    return [
      ModelReasoning.automatic,
      ModelReasoning.minimal,
      ..._standard.skip(1),
    ];
  }
  if (model == 'o1' || model.startsWith('o3') || model.startsWith('o4-mini')) {
    return _standard;
  }
  return _defaultOnly;
}

Map<String, Object?> modelReasoningParameters(ModelConfig config) {
  final effort = config.reasoning;
  if (effort == ModelReasoning.automatic) return const {};
  if (!modelReasoningOptions(
    config.service,
    config.model,
    config.baseUrl,
  ).contains(effort)) {
    throw const ModelProviderException('当前模型不支持所选思考设置，请在模型设置中重新选择');
  }
  return switch (config.service) {
    ModelService.openAi || ModelService.deepSeek || ModelService.openRouter => {
      'reasoning': {'effort': effort.name},
    },
    ModelService.qwen => {'enable_thinking': effort == ModelReasoning.enabled},
    ModelService.kimi || ModelService.glm => {
      'thinking': {
        'type': effort == ModelReasoning.none ? 'disabled' : 'enabled',
      },
    },
  };
}
