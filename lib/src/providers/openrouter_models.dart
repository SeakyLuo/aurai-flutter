import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/model_provider.dart';

class OpenRouterModelInfo {
  OpenRouterModelInfo(this.data);
  final Map<String, dynamic> data;
  String get name => data['name'] as String;
  int get contextWindow => data['context_length'] as int;
  int? get maxOutput =>
      (data['top_provider'] as Map)['max_completion_tokens'] as int?;
  List<String> get inputModalities =>
      List<String>.from(data['architecture']['input_modalities'] as List);
  List<String> get outputModalities =>
      List<String>.from(data['architecture']['output_modalities'] as List);
  bool get supportsImages =>
      (data['architecture']['input_modalities'] as List).contains('image');
  bool get supportsText =>
      (data['architecture']['output_modalities'] as List).contains('text');
  bool supports(String parameter) =>
      (data['supported_parameters'] as List).contains(parameter);
}

abstract final class OpenRouterModels {
  static const _storageKey = 'openrouter_model_capabilities';
  static final _preferences = SharedPreferencesAsync();
  static Map<String, dynamic> _catalogs = {};
  static String _endpoint(String base) =>
      base.endsWith('/') ? base.substring(0, base.length - 1) : base;

  static Future<void> initialize() async {
    final saved = await _preferences.getString(_storageKey);
    if (saved != null) _catalogs = jsonDecode(saved) as Map<String, dynamic>;
  }

  static Future<void> save(
    String baseUrl,
    List<Map<String, dynamic>> models,
  ) async {
    final catalog = <String, dynamic>{
      for (final model in models)
        model['id'] as String: {
          for (final key in [
            'name',
            'context_length',
            'top_provider',
            'architecture',
            'supported_parameters',
          ])
            key: model[key],
        },
    };
    final next = {..._catalogs, _endpoint(baseUrl): catalog};
    await _preferences.setString(_storageKey, jsonEncode(next));
    _catalogs = next;
  }

  static OpenRouterModelInfo? lookup(String baseUrl, String model) {
    final data = (_catalogs[_endpoint(baseUrl)] as Map?)?[model];
    return data == null
        ? null
        : OpenRouterModelInfo(Map<String, dynamic>.from(data as Map));
  }

  static OpenRouterModelInfo? forConfig(ModelConfig config) {
    if (config.service != ModelService.openRouter) return null;
    final info = lookup(config.baseUrl, config.model);
    if (info == null)
      throw const ModelProviderException('请在 OpenRouter 设置中重新选择模型并保存，以获取模型能力');
    if (!info.supportsText)
      throw const ModelProviderException('该模型不支持文字回复，请选择聊天模型');
    return info;
  }
}
