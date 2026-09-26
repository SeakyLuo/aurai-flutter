import 'openrouter_models.dart';
import '../domain/error_message.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/model_provider.dart';

class ModelCatalog {
  final _client = HttpClient()..connectionTimeout = const Duration(seconds: 15);

  Future<List<String>> loadFor(ModelConfig config, {bool textOnly = false}) {
    final models = config.protocol.modelCatalog;
    if (models.isNotEmpty) {
      return Future.value([for (final model in models) model.id]);
    }
    return load(
      baseUrl: Uri.parse(config.baseUrl),
      apiKey: config.apiKey,
      openRouter: config.service.usesOpenRouterCatalog,
      textOnly: textOnly,
    );
  }

  Future<List<String>> load({
    required Uri baseUrl,
    required String apiKey,
    bool openRouter = false,
    bool textOnly = true,
  }) async {
    try {
      return await _load(
        baseUrl,
        apiKey,
        openRouter,
        textOnly,
      ).timeout(const Duration(seconds: 20));
    } on TimeoutException catch (error) {
      throw ModelProviderException('获取模型超时，请检查网络后重试', detail: error.toString());
    } on SocketException catch (error) {
      throw ModelProviderException(
        '无法连接服务，请检查网络和服务地址：${errorMessage(error)}',
        detail: error.toString(),
      );
    } on HandshakeException catch (error) {
      throw ModelProviderException(
        '安全连接失败，请检查服务地址和证书：${errorMessage(error)}',
        detail: error.toString(),
      );
    } on FormatException catch (error) {
      throw ModelProviderException('该服务没有返回有效的模型列表', detail: error.toString());
    }
  }

  Future<List<String>> _load(
    Uri baseUrl,
    String apiKey,
    bool openRouter,
    bool textOnly,
  ) async {
    final path = baseUrl.path.endsWith('/')
        ? '${baseUrl.path}models'
        : '${baseUrl.path}/models';
    final request = await _client.getUrl(
      baseUrl.replace(
        path: path,
        queryParameters: openRouter && !textOnly
            ? {'output_modalities': 'all'}
            : null,
      ),
    );
    request.followRedirects = false;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
    final response = await request.close();
    if (response.statusCode != 200) {
      throw ModelProviderException(switch (response.statusCode) {
        401 || 403 => '密钥无效或没有访问权限，请检查密钥',
        404 => '该地址不支持获取模型，请检查服务地址',
        429 => '请求过于频繁或额度不足，请稍后再试',
        _ => '获取模型失败，请检查服务地址后重试',
      });
    }
    final body = await utf8.decoder.bind(response).join();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final entries = (json['data'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    if (openRouter) await OpenRouterModels.save(baseUrl.toString(), entries);
    final models =
        entries
            .where(
              (entry) =>
                  !openRouter ||
                  !textOnly ||
                  OpenRouterModelInfo(entry).supportsText,
            )
            .map((entry) => entry['id'] as String)
            .toSet()
            .toList()
          ..sort();
    return models;
  }

  void close() => _client.close(force: true);
}

String modelDisplayName(String model) => switch (model) {
  'gpt-5.4-mini' => 'GPT 5.4 Mini',
  'deepseek-flash' => 'DeepSeek Flash',
  'deepseek-v4-flash' => 'DeepSeek V4 Flash',
  'deepseek-v4-pro' => 'DeepSeek V4 Pro',
  'qwen-plus' => '千问 Plus',
  'kimi-k2.6' => 'Kimi K2.6',
  'glm-4.7' => 'GLM 4.7',
  _ => model,
};
