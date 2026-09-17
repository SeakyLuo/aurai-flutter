import '../domain/model_provider.dart';
import '../platform/aurai_platform.dart';
import 'model_balance.dart';

abstract final class ModelTopUp {
  static const deepSeekUrl = 'https://platform.deepseek.com/top_up';

  static String consoleUrl(ModelService service) => switch (service) {
    ModelService.openAi =>
      'https://platform.openai.com/settings/organization/billing/overview',
    ModelService.deepSeek => deepSeekUrl,
    ModelService.qwen =>
      'https://bailian.console.aliyun.com/cn-beijing/costing-balance/overview',
    ModelService.kimi => 'https://platform.kimi.com',
    ModelService.openRouter => 'https://openrouter.ai/settings/credits',
    ModelService.glm => 'https://open.bigmodel.cn/finance/overview',
  };

  static Future<void> openConsole(ModelService service) async {
    await AuraiPlatform.instance.startIntent({
      'action': 'android.intent.action.VIEW',
      'data': consoleUrl(service),
    });
  }

  static Future<void> open(ModelConfig config) async {
    if (config.service != ModelService.deepSeek ||
        !ModelBalanceClient.supports(config)) {
      throw const ModelProviderException('当前仅接入 DeepSeek 官方账户充值，请到对应服务商处理');
    }
    await AuraiPlatform.instance.startIntent({
      'action': 'android.intent.action.VIEW',
      'data': deepSeekUrl,
    });
  }
}
