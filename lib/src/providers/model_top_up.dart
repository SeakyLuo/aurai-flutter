import '../domain/model_provider.dart';
import '../platform/aurai_platform.dart';
import 'model_balance.dart';

abstract final class ModelTopUp {
  static const deepSeekUrl = 'https://platform.deepseek.com/top_up';

  static Future<void> open(ModelConfig config) async {
    if (!ModelBalanceClient.supports(config)) {
      throw const ModelProviderException('当前仅接入 DeepSeek 官方账户充值，请到对应服务商处理');
    }
    await AuraiPlatform.instance.startIntent({
      'action': 'android.intent.action.VIEW',
      'data': deepSeekUrl,
    });
  }
}
