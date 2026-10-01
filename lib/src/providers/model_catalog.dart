import 'model_type_recognition.dart';
import 'openrouter_models.dart';
import 'model_purpose_catalog.dart';
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
      config: config,
      baseUrl: Uri.parse(config.baseUrl),
      apiKey: config.apiKey,
      openRouter: config.service.usesOpenRouterCatalog,
      textOnly: textOnly,
    );
  }

  Future<List<String>> load({
    ModelConfig? config,
    required Uri baseUrl,
    required String apiKey,
    bool openRouter = false,
    bool textOnly = true,
  }) async {
    return await _load(
      config,
      baseUrl,
      apiKey,
      openRouter,
      textOnly,
    ).timeout(const Duration(seconds: 20));
  }

  Future<List<String>> _load(
    ModelConfig? config,
    Uri baseUrl,
    String apiKey,
    bool openRouter,
    bool textOnly,
  ) async {
    final entries = await _fetchEntries(baseUrl, apiKey, openRouter, textOnly);
    if (openRouter) await OpenRouterModels.save(baseUrl.toString(), entries);
    final detected = <String, Set<ModelPurpose>>{};
    for (final entry in entries) {
      final purposes = ModelTypeRecognition.purposes(
        entry,
        config?.details?.modelPurposeField ?? '',
        config?.details?.modelTypeMappings ?? const {},
      );
      if (purposes.isNotEmpty) detected[entry['id'] as String] = purposes;
    }
    await DetectedModelPurposes.save(baseUrl.toString(), detected);
    final models =
        entries
            .where(
              (entry) =>
                  !openRouter ||
                  !textOnly ||
                  OpenRouterModelInfo(entry).supportsText,
            )
            .where((entry) {
              if (!textOnly || openRouter) return true;
              final purposes = detected[entry['id'] as String];
              return purposes == null || purposes.contains(ModelPurpose.text);
            })
            .map((entry) => entry['id'] as String)
            .toSet()
            .toList()
          ..sort();
    return models;
  }

  Future<List<Map<String, dynamic>>> loadEntries(ModelConfig config) =>
      _fetchEntries(
        Uri.parse(config.baseUrl),
        config.apiKey,
        config.service.usesOpenRouterCatalog,
        false,
      ).timeout(const Duration(seconds: 20));

  Future<List<Map<String, dynamic>>> _fetchEntries(
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
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode != 200) {
      throw ModelProviderException(
        response.reasonPhrase,
        statusCode: response.statusCode,
        detail: body,
      );
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    final entries = (json['data'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    return entries;
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
