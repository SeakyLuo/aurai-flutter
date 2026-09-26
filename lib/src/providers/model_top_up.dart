import '../domain/model_provider.dart';
import '../platform/aurai_platform.dart';

abstract final class ModelTopUp {
  static Future<void> open(ModelConfig config) async {
    final url = config.rechargeUrl;
    if (url.isEmpty) throw const ModelProviderException('该供应商未配置充值入口');
    await AuraiPlatform.instance.startIntent({
      'action': 'android.intent.action.VIEW',
      'data': url,
    });
  }
}
