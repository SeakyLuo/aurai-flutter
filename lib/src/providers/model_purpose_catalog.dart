import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/model_provider.dart';
import 'openrouter_models.dart';

abstract final class DetectedModelPurposes {
  static const _storageKey = 'detected_model_purposes';
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
    Map<String, Set<ModelPurpose>> purposes,
  ) async {
    final next = {
      ..._catalogs,
      _endpoint(baseUrl): {
        for (final entry in purposes.entries)
          entry.key: [for (final purpose in entry.value) purpose.name],
      },
    };
    await _preferences.setString(_storageKey, jsonEncode(next));
    _catalogs = next;
  }

  static Set<ModelPurpose>? lookup(String baseUrl, String model) {
    final values = (_catalogs[_endpoint(baseUrl)] as Map?)?[model] as List?;
    if (values == null) return null;
    return {
      for (final value in values) ModelPurpose.values.byName(value as String),
    };
  }
}

Set<ModelPurpose> modelPurposesFor(ModelConfig config, String model) {
  final configured = config.details?.modelPurposes[model];
  if (configured != null) return configured;
  final preset = config.service.presetModelPurposes[model];
  if (preset != null) return preset;
  final name = model.split('/').last;
  if (name.startsWith('gpt-image-') || name == 'chatgpt-image-latest') {
    return {ModelPurpose.imageGeneration};
  }
  if (config.service.staticImageModelIds.contains(model)) {
    return {ModelPurpose.imageGeneration};
  }
  final detected = DetectedModelPurposes.lookup(config.baseUrl, model);
  if (detected != null && detected.isNotEmpty) return detected;
  if (config.protocol.defaultModelPurposes.isNotEmpty) {
    return config.protocol.defaultModelPurposes;
  }
  if (config.service.usesOpenRouterCatalog) {
    final info = OpenRouterModels.lookup(config.baseUrl, model);
    if (info != null) {
      return {
        if (info.outputModalities.contains('text')) ModelPurpose.text,
        if (info.outputModalities.contains('image'))
          ModelPurpose.imageGeneration,
        if (info.outputModalities.contains('video'))
          ModelPurpose.videoGeneration,
      };
    }
  }
  if (RegExp(r'^gpt-(5|6)([.-]|$)').hasMatch(name)) {
    return {ModelPurpose.text};
  }
  if (config.service.defaultModelPurposes.isNotEmpty) {
    return config.service.defaultModelPurposes;
  }
  return {};
}
