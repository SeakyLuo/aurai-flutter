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
  });

  final int contextWindow;
  final int outputTokens;
  static const toolReserve = 16384;
  static const estimated = ModelContextLimits(
    contextWindow: 65536,
    outputTokens: 8192,
  );

  int get inputBudget => contextWindow - outputTokens - toolReserve;
  int get compactThreshold => inputBudget * 80 ~/ 100;
  int get compactTarget => inputBudget * 60 ~/ 100;
  int get summaryBatchBudget => math.min(128000, compactTarget);

  // Unknown models use an estimated 64K window until their capacity is known.
  static ModelContextLimits forModel(String model) => switch (model) {
    'gpt-5.4-mini' || 'gpt-5.4-mini-2026-03-17' => const ModelContextLimits(
      contextWindow: 400000,
      outputTokens: 128000,
    ),
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
