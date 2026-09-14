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
    this.service = ModelService.deepSeek,
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
    final base = Uri.tryParse(config.baseUrl);
    final host = switch (config.service) {
      ModelService.deepSeek => 'api.deepseek.com',
      ModelService.kimi => 'api.moonshot.cn',
      _ => null,
    };
    return host != null &&
        base != null &&
        base.scheme == 'https' &&
        base.host == host &&
        base.port == 443 &&
        base.userInfo.isEmpty &&
        !base.hasQuery &&
        !base.hasFragment &&
        const {'', '/', '/v1', '/v1/'}.contains(base.path);
  }

  Future<ModelBalance> load(ModelConfig config) async {
    if (config.service != ModelService.deepSeek &&
        config.service != ModelService.kimi) {
      throw const ModelProviderException('暂未接入该模型服务的余额查询');
    }
    if (!config.isConfigured) {
      throw ModelProviderException('请先在模型设置中配置 ${config.service.label} 密钥');
    }
    if (!supports(config)) {
      throw const ModelProviderException('当前为自定义服务地址，尚未接入该服务的余额查询');
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
        '无法连接 ${config.service.label}，请检查网络',
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
        '${config.service.label} 未返回有效的余额数据',
        detail: error.toString(),
      );
    } on TypeError catch (error) {
      throw ModelProviderException(
        '${config.service.label} 返回的余额数据格式不符合接口约定',
        detail: error.toString(),
      );
    } finally {
      client.close(force: true);
      if (identical(_client, client)) _client = null;
    }
  }

  Future<ModelBalance> _load(HttpClient client, ModelConfig config) async {
    final kimi = config.service == ModelService.kimi;
    final request = await client.getUrl(
      kimi
          ? Uri.https('api.moonshot.cn', '/v1/users/me/balance')
          : Uri.https('api.deepseek.com', '/user/balance'),
    );
    request.followRedirects = false;
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer ${config.apiKey}',
    );
    final response = await request.close();
    if (response.statusCode != 200) {
      throw ModelProviderException(switch (response.statusCode) {
        401 || 403 => '${config.service.label} 密钥无效或无权查询余额，请检查模型设置',
        429 => '余额查询过于频繁，请稍后再试',
        _ => '${config.service.label} 余额查询失败，请稍后重试',
      });
    }
    final json = jsonDecode(await utf8.decoder.bind(response).join()) as Map;
    if (kimi) {
      if (json['status'] != true) {
        throw const ModelProviderException('Kimi 余额查询失败，请稍后重试');
      }
      final data = json['data'] as Map;
      return ModelBalance(
        service: config.service,
        available: (data['available_balance'] as num) > 0,
        checkedAt: DateTime.now(),
        balances: [
          CurrencyBalance(
            currency: 'CNY',
            total: (data['available_balance'] as num).toString(),
            toppedUp: (data['cash_balance'] as num).toString(),
            granted: (data['voucher_balance'] as num).toString(),
          ),
        ],
      );
    }
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
