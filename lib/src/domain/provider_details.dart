import 'request_adapter.dart';
import 'model_defaults.dart';
import 'model_reasoning.dart';
import 'provider_balance_config.dart';
import 'music_generation_models.dart';
export 'provider_balance_config.dart';

class ModelContextOverride {
  const ModelContextOverride({this.contextWindow, this.compactPercent});

  final int? contextWindow;
  final int? compactPercent;

  Map<String, Object?> toJson() => {
    if (contextWindow != null) 'contextWindow': contextWindow,
    if (compactPercent != null) 'compactPercent': compactPercent,
  };

  factory ModelContextOverride.fromJson(Map<String, dynamic> json) =>
      ModelContextOverride(
        contextWindow: json['contextWindow'] as int?,
        compactPercent: json['compactPercent'] as int?,
      );
}

enum ProviderProtocol {
  openaiChatCompletions('Chat Completions'),
  responses('Responses'),
  suno(
    'Suno API',
    supportsChatModels: false,
    modelCatalog: MusicGenerationModels.values,
    defaultModelPurposes: {ModelPurpose.musicGeneration},
    supportedModelPurposes: {ModelPurpose.musicGeneration},
  );

  const ProviderProtocol(
    this.label, {
    this.supportsChatModels = true,
    this.modelCatalog = const [],
    this.defaultModelPurposes = const {},
    this.supportedModelPurposes = const {
      ModelPurpose.text,
      ModelPurpose.imageGeneration,
      ModelPurpose.videoGeneration,
    },
  });
  final String label;
  final bool supportsChatModels;
  final List<({String id, String name})> modelCatalog;
  final Set<ModelPurpose> defaultModelPurposes;
  final Set<ModelPurpose> supportedModelPurposes;

  String displayModel(String id) {
    for (final model in modelCatalog) {
      if (model.id == id) return model.name;
    }
    return id;
  }
}

enum ProviderIcon {
  letter('字母图标', ''),
  openAi('OpenAI', 'openai', monochrome: true),
  deepSeek('DeepSeek', 'deepseek-color'),
  qwen('千问', 'qwen-color'),
  kimi('Kimi', 'kimi-color'),
  glm('GLM', 'zhipu-color'),
  openRouter('OpenRouter', 'openrouter-grape'),
  suno('Suno', 'suno', monochrome: true);

  const ProviderIcon(this.label, this.asset, {this.monochrome = false});
  final String label;
  final String asset;
  final bool monochrome;
}

class ProviderDetails {
  const ProviderDetails({
    required this.name,
    required this.website,
    required this.protocol,
    this.models = const [],
    this.requestAdapters = const {},
    this.modelContextOverrides = const {},
    this.modelPurposes = const {},
    this.modelReasoning = const {},
    this.autoSyncModels = true,
    this.balance,
    this.icon,
  });
  final Map<String, RequestAdapter> requestAdapters;
  final Map<String, ModelContextOverride> modelContextOverrides;
  final Map<String, Set<ModelPurpose>> modelPurposes;
  final Map<String, ModelReasoning> modelReasoning;
  final String name;
  final String website;
  final ProviderProtocol protocol;
  final List<String> models;
  // 热重载保留的旧实例没有此字段；null 表示尚未设置，使用实时同步。
  final bool? autoSyncModels;
  final ProviderBalanceConfig? balance;
  final String? icon;
  Map<String, Object?> toJson() => {
    'requestAdapters': {
      for (final e in requestAdapters.entries) e.key: e.value.toJson(),
    },
    'modelContextOverrides': {
      for (final e in modelContextOverrides.entries) e.key: e.value.toJson(),
    },
    'modelPurposes': {
      for (final e in modelPurposes.entries)
        e.key: [for (final purpose in e.value) purpose.name],
    },
    'modelReasoning': {
      for (final e in modelReasoning.entries) e.key: e.value.name,
    },
    'name': name,
    'website': website,
    'protocol': protocol.name,
    'models': models,
    'autoSyncModels': autoSyncModels ?? true,
    if (balance != null) 'balance': balance!.toJson(),
    if (icon != null) 'icon': icon,
  };
  factory ProviderDetails.fromJson(Map<String, dynamic> json) =>
      ProviderDetails(
        requestAdapters: {
          for (final e in (json['requestAdapters'] as Map? ?? {}).entries)
            e.key as String: RequestAdapter.fromJson(
              Map<String, dynamic>.from(e.value as Map),
            ),
        },
        modelContextOverrides: {
          for (final e in (json['modelContextOverrides'] as Map? ?? {}).entries)
            e.key as String: ModelContextOverride.fromJson(
              Map<String, dynamic>.from(e.value as Map),
            ),
        },
        modelPurposes: {
          for (final e in (json['modelPurposes'] as Map? ?? {}).entries)
            e.key as String: {
              for (final name in e.value as List)
                ModelPurpose.values.byName(name as String),
            },
        },
        modelReasoning: {
          for (final e in (json['modelReasoning'] as Map? ?? {}).entries)
            e.key as String: ModelReasoning.values.byName(e.value as String),
        },
        name: json['name'] as String,
        website: json['website'] as String,
        protocol: ProviderProtocol.values.byName(json['protocol'] as String),
        models: List<String>.from(json['models'] as List),
        autoSyncModels: json['autoSyncModels'] as bool? ?? true,
        balance: json['balance'] == null
            ? null
            : ProviderBalanceConfig.fromJson(
                Map<String, dynamic>.from(json['balance'] as Map),
              ),
        icon: json['icon'] as String?,
      );
}

void validateProviderDetails(ProviderDetails details, String baseUrl) {
  if (details.name.trim().isEmpty || details.name.length > 60) {
    throw ArgumentError('供应商名称需为 1–60 字');
  }
  final api = Uri.tryParse(baseUrl);
  if (api == null ||
      api.scheme != 'https' ||
      api.host.isEmpty ||
      api.userInfo.isNotEmpty ||
      api.hasQuery ||
      api.hasFragment ||
      RegExp(r'/(chat/completions|responses|models)/?$').hasMatch(api.path)) {
    throw ArgumentError(
      '请填写 HTTPS API 根地址，不包含具体接口路径，例如 https://example.com/v1',
    );
  }
  if (details.website.isNotEmpty) {
    final site = Uri.tryParse(details.website);
    if (site == null ||
        site.scheme != 'https' ||
        site.host.isEmpty ||
        site.userInfo.isNotEmpty) {
      throw ArgumentError('请填写有效的 HTTPS 官网地址');
    }
  }
  if (details.balance case final balance?) {
    final endpoint = Uri.tryParse(balance.url);
    if (endpoint == null ||
        endpoint.scheme != 'https' ||
        endpoint.host.isEmpty ||
        endpoint.userInfo.isNotEmpty ||
        endpoint.hasFragment) {
      throw ArgumentError('请填写有效的 HTTPS 余额查询地址');
    }
    if (balance.topUpUrl.isNotEmpty) {
      final topUp = Uri.tryParse(balance.topUpUrl);
      if (topUp == null ||
          topUp.scheme != 'https' ||
          topUp.host.isEmpty ||
          topUp.userInfo.isNotEmpty) {
        throw ArgumentError('请填写有效的 HTTPS 充值地址');
      }
    }
    if (balance.totalPath.isEmpty ||
        balance.toppedUpPath.isEmpty ||
        balance.grantedPath.isEmpty ||
        (balance.currencyPath.isEmpty && balance.currency.isEmpty) ||
        balance.grantedLabel.isEmpty ||
        (balance.successPath.isNotEmpty && balance.successValue.isEmpty)) {
      throw ArgumentError('余额解析配置不完整');
    }
    final pathPattern = RegExp(r'^[^.\s]+(?:\.[^.\s]+)*$');
    for (final path in [
      balance.itemsPath,
      balance.availablePath,
      balance.successPath,
      balance.currencyPath,
      balance.totalPath,
      balance.toppedUpPath,
      balance.grantedPath,
    ]) {
      if (path.isNotEmpty && !pathPattern.hasMatch(path)) {
        throw ArgumentError('余额字段路径格式不正确');
      }
    }
  }
  if (details.models.toSet().length != details.models.length) {
    throw ArgumentError('模型列表中存在重复名称');
  }
  if (details.models.any((m) => m.trim().isEmpty || m.length > 200)) {
    throw ArgumentError('模型名称不能为空或超过 200 字');
  }
  for (final entry in details.modelContextOverrides.entries) {
    if (entry.key.isNotEmpty &&
        (entry.key.trim().isEmpty || entry.key.length > 200)) {
      throw ArgumentError('模型名称不能为空或超过 200 字');
    }
    final window = entry.value.contextWindow;
    final percent = entry.value.compactPercent;
    if (entry.key.isEmpty && window != null) {
      throw ArgumentError('默认模型设置仅支持压缩阈值');
    }
    if (window != null && (window < 32768 || window > 2000000)) {
      throw ArgumentError('上下文窗口需在 32K–2M token 之间');
    }
    if (percent != null && (percent < 65 || percent > 95)) {
      throw ArgumentError('压缩阈值需在 65%–95% 之间');
    }
  }
  for (final entry in details.modelPurposes.entries) {
    if (entry.key.trim().isEmpty || entry.key.length > 200) {
      throw ArgumentError('模型名称不能为空或超过 200 字');
    }
    if (entry.value.isEmpty) throw ArgumentError('请至少选择一种模型用途');
  }
  for (final model in details.modelReasoning.keys) {
    if (model.trim().isEmpty || model.length > 200) {
      throw ArgumentError('模型名称不能为空或超过 200 字');
    }
  }
}
