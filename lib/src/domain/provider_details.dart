import 'request_adapter.dart';

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
  responses('Responses');

  const ProviderProtocol(this.label);
  final String label;
}

class ProviderDetails {
  const ProviderDetails({
    required this.name,
    required this.website,
    required this.protocol,
    this.models = const [],
    this.requestAdapters = const {},
    this.modelContextOverrides = const {},
    this.autoSyncModels = true,
  });
  final Map<String, RequestAdapter> requestAdapters;
  final Map<String, ModelContextOverride> modelContextOverrides;
  final String name;
  final String website;
  final ProviderProtocol protocol;
  final List<String> models;
  // 热重载保留的旧实例没有此字段；null 表示尚未设置，使用实时同步。
  final bool? autoSyncModels;
  Map<String, Object?> toJson() => {
    'requestAdapters': {
      for (final e in requestAdapters.entries) e.key: e.value.toJson(),
    },
    'modelContextOverrides': {
      for (final e in modelContextOverrides.entries) e.key: e.value.toJson(),
    },
    'name': name,
    'website': website,
    'protocol': protocol.name,
    'models': models,
    'autoSyncModels': autoSyncModels ?? true,
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
        name: json['name'] as String,
        website: json['website'] as String,
        protocol: ProviderProtocol.values.byName(json['protocol'] as String),
        models: List<String>.from(json['models'] as List),
        autoSyncModels: json['autoSyncModels'] as bool? ?? true,
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
  if (details.models.toSet().length != details.models.length) {
    throw ArgumentError('模型列表中存在重复名称');
  }
  if (details.models.any((m) => m.trim().isEmpty || m.length > 200)) {
    throw ArgumentError('模型名称不能为空或超过 200 字');
  }
  for (final entry in details.modelContextOverrides.entries) {
    if (entry.key.trim().isEmpty || entry.key.length > 200) {
      throw ArgumentError('模型名称不能为空或超过 200 字');
    }
    final window = entry.value.contextWindow;
    final percent = entry.value.compactPercent;
    if (window != null && (window < 32768 || window > 2000000)) {
      throw ArgumentError('上下文窗口需在 32K–2M token 之间');
    }
    if (percent != null && (percent < 65 || percent > 95)) {
      throw ArgumentError('压缩阈值需在 65%–95% 之间');
    }
  }
}
