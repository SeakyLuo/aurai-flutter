import '../domain/model_provider.dart';
import 'openrouter_models.dart';
import 'dart:math' as math;

/// Official model windows; aliases are listed explicitly so custom model names
/// are never assigned another model's capacity.
/// https://developers.openai.com/api/docs/models/gpt-5.4-mini
/// https://api-docs.deepseek.com/quick_start/pricing/
/// https://api-docs.deepseek.com/quick_start/agent_integrations/codex/
class ModelContextLimits {
  const ModelContextLimits({
    required this.contextWindow,
    required this.outputTokens,
    this.compactPercent = 80,
    this.isEstimated = false,
  });

  final int contextWindow;
  final int outputTokens;
  final int compactPercent;
  final bool isEstimated;
  static const toolReserve = 16384;
  static const estimated = ModelContextLimits(
    contextWindow: 65536,
    outputTokens: 8192,
    isEstimated: true,
  );

  int get inputBudget =>
      contextWindow - outputTokens - math.min(toolReserve, contextWindow ~/ 8);
  int get compactThreshold => inputBudget * compactPercent ~/ 100;
  int get compactTarget => compactThreshold * 3 ~/ 4;
  int get summaryBatchBudget => math.min(128000, compactTarget);

  static ModelContextLimits forConfig(ModelConfig config) {
    final info = OpenRouterModels.forConfig(config);
    final base = info == null ? forModel(config.model) : _forOpenRouter(info);
    return _applyOverride(base, config);
  }

  static ModelContextLimits previewForConfig(ModelConfig config) {
    final info = config.service == ModelService.openRouter
        ? OpenRouterModels.lookup(config.baseUrl, config.model)
        : null;
    final base = info == null ? forModel(config.model) : _forOpenRouter(info);
    return _applyOverride(base, config);
  }

  static ModelContextLimits _forOpenRouter(OpenRouterModelInfo info) =>
      ModelContextLimits(
        contextWindow: info.contextWindow,
        outputTokens: math.min(
          info.maxOutput ?? 8192,
          math.min(32768, info.contextWindow ~/ 4),
        ),
      );

  static ModelContextLimits _applyOverride(
    ModelContextLimits base,
    ModelConfig config,
  ) {
    final override = config.details?.modelContextOverrides[config.model];
    if (override == null) return base;
    final window = override.contextWindow ?? base.contextWindow;
    return ModelContextLimits(
      contextWindow: window,
      outputTokens: override.contextWindow == null
          ? base.outputTokens
          : math.min(base.outputTokens, window ~/ 4),
      compactPercent: override.compactPercent ?? 80,
      isEstimated: override.contextWindow == null && base.isEstimated,
    );
  }

  // Unknown models use an estimated 64K window until their capacity is known.
  static ModelContextLimits forModel(String model) => switch (model) {
    // https://developers.openai.com/api/docs/models/compare
    'gpt-6-astra' ||
    'gpt-6-sol' ||
    'gpt-6-luna' ||
    // DMXAPI names omit the hyphen after GPT.
    'gpt6-astra' ||
    'gpt6-sol' ||
    'gpt6-luna' ||
    'gpt-5.6-sol' ||
    'gpt-5.6-terra' ||
    'gpt-5.6-luna' => const ModelContextLimits(
      contextWindow: 1050000,
      outputTokens: 128000,
    ),
    // https://developers.openai.com/api/docs/models/gpt-4o-mini
    'gpt-4o-mini' || 'gpt-4o-mini-2024-07-18' => const ModelContextLimits(
      contextWindow: 128000,
      outputTokens: 16384,
    ),
    'gpt-5.4-mini' || 'gpt-5.4-mini-2026-03-17' => const ModelContextLimits(
      contextWindow: 400000,
      outputTokens: 128000,
    ),
    'deepseek-flash' ||
    'deepseek-v4.1-flash' ||
    'deepseek-v4-flash' ||
    'deepseek-v4-pro' ||
    'deepseek-v4-flash-vision-exp' => const ModelContextLimits(
      contextWindow: 1048576,
      outputTokens: 384000,
    ),
    // https://www.alibabacloud.com/help/en/model-studio/model-qwen3-max
    'qwen3-max' || 'qwen3-max-2026-01-23' => const ModelContextLimits(
      contextWindow: 262144,
      outputTokens: 32768,
    ),
    // https://help.aliyun.com/zh/model-studio/qwen-plus
    'qwen-plus' || 'qwen-plus-2025-09-11' => const ModelContextLimits(
      contextWindow: 1000000,
      outputTokens: 32768,
    ),
    // https://platform.kimi.ai/docs/guide/kimi-k2-6-quickstart
    // https://www.kimi.com/resources/kimi-k2-6-pricing
    'kimi-k2.6' => const ModelContextLimits(
      contextWindow: 262144,
      outputTokens: 32768,
    ),
    // https://www.alibabacloud.com/help/tc/model-studio/coding-plan-faq
    'glm-4.7' => const ModelContextLimits(
      contextWindow: 202752,
      outputTokens: 32768,
    ),
    // https://docs.bigmodel.cn/cn/guide/models/text/glm-5.2
    'glm-5.2' || 'zhipu/glm-5.2' => const ModelContextLimits(
      contextWindow: 1000000,
      outputTokens: 32768,
    ),
    // https://www.kimi.ai/blog/kimi-k3
    'kimi-k3' || 'kimi/kimi-k3' => const ModelContextLimits(
      contextWindow: 1000000,
      outputTokens: 32768,
    ),
    _ => estimated,
  };
}
