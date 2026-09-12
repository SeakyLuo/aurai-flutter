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

  int get inputBudget => contextWindow - outputTokens - toolReserve;
  int get compactThreshold => inputBudget * 80 ~/ 100;
  int get compactTarget => inputBudget * 60 ~/ 100;
  int get summaryBatchBudget => math.min(128000, compactTarget);

  static ModelContextLimits? forModel(String model) => switch (model) {
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
    _ => null,
  };
}
