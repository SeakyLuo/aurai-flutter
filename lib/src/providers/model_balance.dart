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
    required this.service,
    required this.balances,
    required this.checkedAt,
  });
  final ModelService service;
  final bool available;
  final List<CurrencyBalance> balances;
  final DateTime checkedAt;

  Map<String, Object?> toJson() => {
    'provider': service.label,
    'source': '${service.label} account balance API',
    'availableForApiCalls': available,
    'checkedAt': checkedAt.toUtc().toIso8601String(),
    'balances': balances.map((balance) => balance.toJson()).toList(),
  };
}

class ModelBalanceClient {
  HttpClient? _client;

  static bool supports(ModelConfig config) {
    return config.balanceConfig != null;
  }

  Future<ModelBalance> load(ModelConfig config) async {
    if (config.balanceConfig == null) {
      throw const ModelProviderException('暂未接入该模型服务的余额查询');
    }
    if (!config.isConfigured) {
      throw ModelProviderException('请先在模型设置中配置 ${config.displayName} 密钥');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    _client = client;
    try {
      return await _load(client, config).timeout(const Duration(seconds: 10));
    } finally {
      client.close(force: true);
      if (identical(_client, client)) _client = null;
    }
  }

  Future<ModelBalance> _load(HttpClient client, ModelConfig config) async {
    final balanceConfig = config.balanceConfig!;
    final request = await client.getUrl(Uri.parse(balanceConfig.url));
    request.followRedirects = false;
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer ${config.apiKey}',
    );
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode != 200) {
      throw ModelProviderException(
        response.reasonPhrase,
        statusCode: response.statusCode,
        detail: body,
      );
    }
    final json = jsonDecode(body) as Map;
    if (balanceConfig.successPath.isNotEmpty &&
        _valueAt(json, balanceConfig.successPath).toString() !=
            balanceConfig.successValue) {
      throw ModelProviderException(
        '余额接口返回失败状态',
        statusCode: response.statusCode,
        detail: body,
      );
    }
    final items = balanceConfig.itemsPath.isEmpty
        ? [json]
        : _valueAt(json, balanceConfig.itemsPath) as List;
    final balances = [
      for (final item in items)
        CurrencyBalance(
          currency: balanceConfig.currencyPath.isEmpty
              ? balanceConfig.currency
              : (_valueAt(item as Map, balanceConfig.currencyPath) as String),
          total: (_valueAt(item as Map, balanceConfig.totalPath) as Object)
              .toString(),
          toppedUp: (_valueAt(item, balanceConfig.toppedUpPath) as Object)
              .toString(),
          granted: (_valueAt(item, balanceConfig.grantedPath) as Object)
              .toString(),
        ),
    ];
    return ModelBalance(
      service: config.service,
      available: balanceConfig.availablePath.isEmpty
          ? balances.any((balance) => num.parse(balance.total) > 0)
          : _valueAt(json, balanceConfig.availablePath) as bool,
      checkedAt: DateTime.now(),
      balances: balances,
    );
  }

  Object? _valueAt(Map json, String path) {
    Object? value = json;
    for (final field in path.split('.')) {
      value = (value as Map)[field];
    }
    return value;
  }

  void close() => _client?.close(force: true);
}
