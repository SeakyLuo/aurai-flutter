import '../domain/error_message.dart';
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
    } on TimeoutException catch (error) {
      throw ModelProviderException('查询余额超时，请稍后重试', detail: error.toString());
    } on SocketException catch (error) {
      throw ModelProviderException(
        '无法连接 ${config.displayName}，请检查网络',
        detail: error.toString(),
      );
    } on HandshakeException catch (error) {
      throw ModelProviderException(
        '无法建立安全连接，请稍后重试：${errorMessage(error)}',
        detail: error.toString(),
      );
    } on HttpException catch (error) {
      throw ModelProviderException('余额查询连接中断，请稍后重试', detail: error.toString());
    } on FormatException catch (error) {
      throw ModelProviderException(
        '${config.displayName} 未返回有效的余额数据',
        detail: error.toString(),
      );
    } on TypeError catch (error) {
      throw ModelProviderException(
        '${config.displayName} 返回的余额数据格式不符合接口约定',
        detail: error.toString(),
      );
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
    if (response.statusCode != 200) {
      throw ModelProviderException(switch (response.statusCode) {
        401 || 403 => '${config.displayName} 密钥无效或无权查询余额，请检查模型设置',
        429 => '余额查询过于频繁，请稍后再试',
        _ => '${config.displayName} 余额查询失败，请稍后重试',
      });
    }
    final json = jsonDecode(await utf8.decoder.bind(response).join()) as Map;
    if (balanceConfig.successPath.isNotEmpty &&
        _valueAt(json, balanceConfig.successPath).toString() !=
            balanceConfig.successValue) {
      throw ModelProviderException('${config.displayName} 余额查询失败，请稍后重试');
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
