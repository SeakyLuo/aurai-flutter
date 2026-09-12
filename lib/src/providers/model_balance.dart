import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/model_provider.dart';

class CurrencyBalance {
  const CurrencyBalance({
    required this.currency,
    required this.total,
    required this.toppedUp,
    required this.granted,
  });
  final String currency;
  final String total;
  final String toppedUp;
  final String granted;

  Map<String, Object?> toJson() => {
    'currency': currency,
    'totalBalance': total,
    'toppedUpBalance': toppedUp,
    'grantedBalance': granted,
  };
}

class ModelBalance {
  const ModelBalance({
    required this.available,
    required this.balances,
    required this.checkedAt,
  });
  final bool available;
  final List<CurrencyBalance> balances;
  final DateTime checkedAt;

  Map<String, Object?> toJson() => {
    'provider': 'DeepSeek',
    'source': 'DeepSeek account balance API',
    'availableForApiCalls': available,
    'checkedAt': checkedAt.toUtc().toIso8601String(),
    'balances': balances.map((balance) => balance.toJson()).toList(),
  };
}

class ModelBalanceClient {
  HttpClient? _client;

  static bool supports(ModelConfig config) {
    final base = Uri.tryParse(config.baseUrl);
    return config.service == ModelService.deepSeek &&
        base != null &&
        base.scheme == 'https' &&
        base.host == 'api.deepseek.com' &&
        base.port == 443 &&
        base.userInfo.isEmpty &&
        !base.hasQuery &&
        !base.hasFragment &&
        const {'', '/', '/v1', '/v1/'}.contains(base.path);
  }

  Future<ModelBalance> load(ModelConfig config) async {
    if (config.service != ModelService.deepSeek) {
      throw const ModelProviderException('暂未接入该模型服务的余额查询');
    }
    if (!config.isConfigured) {
      throw const ModelProviderException('请先在模型设置中配置 DeepSeek 密钥');
    }
    if (!supports(config)) {
      throw const ModelProviderException('当前为自定义服务地址，尚未接入该服务的余额查询');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    _client = client;
    try {
      return await _load(
        client,
        config.apiKey,
      ).timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw const ModelProviderException('查询余额超时，请稍后重试');
    } on SocketException {
      throw const ModelProviderException('无法连接 DeepSeek，请检查网络');
    } on HandshakeException {
      throw const ModelProviderException('无法建立安全连接，请稍后重试');
    } on HttpException {
      throw const ModelProviderException('余额查询连接中断，请稍后重试');
    } on FormatException {
      throw const ModelProviderException('DeepSeek 未返回有效的余额数据');
    } on TypeError {
      throw const ModelProviderException('DeepSeek 返回的余额数据格式不符合接口约定');
    } finally {
      client.close(force: true);
      if (identical(_client, client)) _client = null;
    }
  }

  Future<ModelBalance> _load(HttpClient client, String apiKey) async {
    final request = await client.getUrl(
      Uri.https('api.deepseek.com', '/user/balance'),
    );
    request.followRedirects = false;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
    final response = await request.close();
    if (response.statusCode != 200) {
      throw ModelProviderException(switch (response.statusCode) {
        401 || 403 => 'DeepSeek 密钥无效或无权查询余额，请检查模型设置',
        429 => '余额查询过于频繁，请稍后再试',
        _ => 'DeepSeek 余额查询失败，请稍后重试',
      });
    }
    final json = jsonDecode(await utf8.decoder.bind(response).join()) as Map;
    return ModelBalance(
      available: json['is_available'] as bool,
      checkedAt: DateTime.now(),
      balances: (json['balance_infos'] as List)
          .map(
            (item) => CurrencyBalance(
              currency: item['currency'] as String,
              total: item['total_balance'] as String,
              toppedUp: item['topped_up_balance'] as String,
              granted: item['granted_balance'] as String,
            ),
          )
          .toList(),
    );
  }

  void close() => _client?.close(force: true);
}
