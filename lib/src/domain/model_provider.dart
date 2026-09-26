import 'dart:math';
import 'provider_details.dart';
export 'provider_details.dart';
import 'model_defaults.dart';
export 'model_defaults.dart';
import 'model_reasoning.dart';
export 'model_reasoning.dart';
import 'dart:convert';
import 'response_preferences.dart';
export 'response_preferences.dart';
import 'agent_models.dart';
import 'context_summary.dart';
import 'capability.dart';
import 'tool_models.dart';

class ModelService {
  const ModelService._(
    this.name,
    this.defaultProtocol, {
    this.presetLabel,
    this.defaultModel = '',
    this.defaultBaseUrl = '',
    this.defaultWebsite = '',
    this.defaultBalance,
    this.defaultConsoleUrl = '',
    this.defaultIcon = ProviderIcon.letter,
    this.defaultIconText,
    this.supportsImageGeneration = false,
    this.usesOpenRouterCatalog = false,
    this.defaultModelPurposes = const {},
    this.staticImageModelIds = const {},
    this.useOpenAiTransport = false,
    this.disableReasoningForSummary = false,
  });
  final String name;
  final ProviderProtocol defaultProtocol;
  final String? presetLabel;
  final String defaultModel;
  final String defaultBaseUrl;
  final String defaultWebsite;
  final ProviderBalanceConfig? defaultBalance;
  final String defaultConsoleUrl;
  final ProviderIcon defaultIcon;
  final String? defaultIconText;
  final bool supportsImageGeneration;
  final bool usesOpenRouterCatalog;
  final Set<ModelPurpose> defaultModelPurposes;
  final Set<String> staticImageModelIds;
  final bool useOpenAiTransport;
  final bool disableReasoningForSummary;
  static const openAi = ModelService._(
    'openAi',
    ProviderProtocol.responses,
    presetLabel: 'OpenAI',
    defaultModel: 'gpt-5.4-mini',
    defaultBaseUrl: 'https://api.openai.com/v1',
    defaultWebsite: 'https://openai.com',
    defaultIcon: ProviderIcon.openAi,
    useOpenAiTransport: true,
    defaultConsoleUrl:
        'https://platform.openai.com/settings/organization/billing/overview',
  );
  static const deepSeek = ModelService._(
    'deepSeek',
    ProviderProtocol.responses,
    presetLabel: 'DeepSeek',
    defaultModel: 'deepseek-flash',
    defaultBaseUrl: 'https://api.deepseek.com',
    defaultWebsite: 'https://www.deepseek.com',
    defaultIcon: ProviderIcon.deepSeek,
    defaultModelPurposes: {ModelPurpose.text},
    disableReasoningForSummary: true,
    defaultConsoleUrl: 'https://platform.deepseek.com/top_up',
    defaultBalance: ProviderBalanceConfig(
      url: 'https://api.deepseek.com/user/balance',
      itemsPath: 'balance_infos',
      availablePath: 'is_available',
      currencyPath: 'currency',
      totalPath: 'total_balance',
      toppedUpPath: 'topped_up_balance',
      grantedPath: 'granted_balance',
      topUpUrl: 'https://platform.deepseek.com/top_up',
    ),
  );
  static const qwen = ModelService._(
    'qwen',
    ProviderProtocol.openaiChatCompletions,
    presetLabel: '千问',
    defaultModel: 'qwen-plus',
    defaultBaseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    defaultWebsite: 'https://bailian.console.aliyun.com',
    defaultIcon: ProviderIcon.qwen,
    supportsImageGeneration: true,
    staticImageModelIds: {
      'qwen-image-3.0-pro',
      'qwen-image-3.0',
      'qwen-image-max',
    },
    defaultConsoleUrl:
        'https://bailian.console.aliyun.com/cn-beijing/costing-balance/overview',
  );
  static const kimi = ModelService._(
    'kimi',
    ProviderProtocol.openaiChatCompletions,
    presetLabel: 'Kimi',
    defaultModel: 'kimi-k2.6',
    defaultBaseUrl: 'https://api.moonshot.cn/v1',
    defaultWebsite: 'https://platform.moonshot.cn',
    defaultIcon: ProviderIcon.kimi,
    defaultModelPurposes: {ModelPurpose.text},
    defaultConsoleUrl: 'https://platform.kimi.com',
    defaultBalance: ProviderBalanceConfig(
      url: 'https://api.moonshot.cn/v1/users/me/balance',
      successPath: 'status',
      currency: 'CNY',
      totalPath: 'data.available_balance',
      toppedUpPath: 'data.cash_balance',
      grantedPath: 'data.voucher_balance',
      grantedLabel: '代金券',
    ),
  );
  static const glm = ModelService._(
    'glm',
    ProviderProtocol.openaiChatCompletions,
    presetLabel: 'GLM',
    defaultModel: 'glm-4.7',
    defaultBaseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    defaultWebsite: 'https://open.bigmodel.cn',
    defaultIcon: ProviderIcon.glm,
    defaultModelPurposes: {ModelPurpose.text},
    defaultConsoleUrl: 'https://open.bigmodel.cn/finance/overview',
  );
  static const openRouter = ModelService._(
    'openRouter',
    ProviderProtocol.openaiChatCompletions,
    presetLabel: 'OpenRouter',
    defaultModel: 'openai/gpt-5.6-sol',
    defaultBaseUrl: 'https://openrouter.ai/api/v1',
    defaultWebsite: 'https://openrouter.ai',
    defaultIcon: ProviderIcon.openRouter,
    supportsImageGeneration: true,
    usesOpenRouterCatalog: true,
    defaultConsoleUrl: 'https://openrouter.ai/settings/credits',
  );
  static const dmxapi = ModelService._(
    'dmxapi',
    ProviderProtocol.openaiChatCompletions,
    presetLabel: 'DMXAPI',
    defaultModel: 'gpt-4o-mini',
    defaultBaseUrl: 'https://www.dmxapi.cn/v1',
    defaultWebsite: 'https://www.dmxapi.cn',
    defaultIconText: 'DMX',
    defaultConsoleUrl: 'https://www.dmxapi.cn',
  );
  static const suno = ModelService._(
    'suno',
    ProviderProtocol.suno,
    presetLabel: 'Suno',
    defaultModel: 'chirp-hawk',
    defaultBaseUrl: 'https://open.suno.cn/api/v1',
    defaultWebsite: 'https://open.suno.cn',
    defaultIcon: ProviderIcon.suno,
    defaultConsoleUrl: 'https://open.suno.cn',
  );
  static const values = [
    openAi,
    suno,
    deepSeek,
    qwen,
    kimi,
    glm,
    openRouter,
    dmxapi,
  ];

  factory ModelService.custom(String label) {
    if (label.trim().isEmpty || label.length > 60) {
      throw ArgumentError('供应商名称需为 1–60 字');
    }
    return ModelService._(
      'custom:${label.trim()}',
      ProviderProtocol.openaiChatCompletions,
    );
  }
  factory ModelService.create() => ModelService._(
    'provider:${List.generate(16, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, "0")).join()}',
    ProviderProtocol.openaiChatCompletions,
  );

  static ModelService byName(String name) {
    if (name.startsWith('provider:')) {
      return ModelService._(name, ProviderProtocol.openaiChatCompletions);
    }
    if (name.startsWith('custom:'))
      return ModelService.custom(name.substring(7));
    return values.firstWhere((service) => service.name == name);
  }

  bool get isCustom =>
      name.startsWith('custom:') || name.startsWith('provider:');
  @override
  bool operator ==(Object other) => other is ModelService && other.name == name;
  @override
  int get hashCode => name.hashCode;
}

extension ModelServiceDetails on ModelService {
  String get label =>
      presetLabel ??
      (name.startsWith('custom:') ? name.substring(7) : '自定义供应商');
}

class ModelConfig {
  const ModelConfig({
    required this.apiKey,
    this.service = ModelService.openAi,
    required this.model,
    required this.baseUrl,
    this.reasoning = ModelReasoning.automatic,
    this.details,
  });

  factory ModelConfig.defaults(ModelService service, {String apiKey = ''}) =>
      ModelConfig(
        service: service,
        apiKey: apiKey,
        model: service.defaultModel,
        baseUrl: service.defaultBaseUrl,
      );

  final ModelService service;
  final String apiKey;
  final String model;
  final String baseUrl;
  final ModelReasoning reasoning;
  final ProviderDetails? details;
  String get displayName => details?.name ?? service.label;
  String? get icon => details?.icon;
  String get website => details?.website ?? service.defaultWebsite;
  ProviderProtocol get protocol => details?.protocol ?? service.defaultProtocol;
  ProviderBalanceConfig? get balanceConfig {
    if (details?.balance case final configured?) return configured;
    final preset = service.defaultBalance;
    if (preset == null) return null;
    final base = Uri.parse(baseUrl);
    final official = Uri.parse(service.defaultBaseUrl);
    return base.scheme == 'https' &&
            base.host == official.host &&
            base.port == official.port &&
            const {'', '/', '/v1', '/v1/'}.contains(base.path) &&
            base.userInfo.isEmpty &&
            !base.hasQuery &&
            !base.hasFragment
        ? preset
        : null;
  }

  String get rechargeUrl {
    final topUp = balanceConfig?.topUpUrl;
    if (topUp != null && topUp.isNotEmpty) return topUp;
    return service.defaultConsoleUrl.isNotEmpty
        ? service.defaultConsoleUrl
        : website;
  }

  bool get usesChatCompletions =>
      protocol == ProviderProtocol.openaiChatCompletions;
  bool get autoSyncModels => details?.autoSyncModels ?? true;
  List<String> get savedModels => details?.models ?? const [];
  ModelReasoning reasoningFor(String model) =>
      details?.modelReasoning[model] ?? reasoning;
  ModelConfig copyWith({
    String? apiKey,
    String? model,
    String? baseUrl,
    ModelReasoning? reasoning,
    ProviderDetails? details,
  }) => ModelConfig(
    service: service,
    apiKey: apiKey ?? this.apiKey,
    model: model ?? this.model,
    baseUrl: baseUrl ?? this.baseUrl,
    reasoning: reasoning ?? this.reasoning,
    details: details ?? this.details,
  );

  bool get isConfigured => apiKey.isNotEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
    'service': service.name,
    'apiKey': apiKey,
    'model': model,
    'baseUrl': baseUrl,
    'reasoning': reasoning.name,
    if (details != null) 'providerDetails': details!.toJson(),
  };

  factory ModelConfig.fromJson(Map<String, Object?> json) => ModelConfig(
    details: json['providerDetails'] == null
        ? null
        : ProviderDetails.fromJson(
            Map<String, dynamic>.from(json['providerDetails'] as Map),
          ),
    service: _serviceFromStored(json['service']! as String),
    apiKey: json['apiKey']! as String,
    model: json['model']! as String,
    baseUrl: json['baseUrl']! as String,
    reasoning: ModelReasoning.values.byName(
      json['reasoning'] as String? ?? 'automatic',
    ),
  );
}

class ModelSettings {
  const ModelSettings({
    required this.activeService,
    required this.profiles,
    this.systemPrompt,
    this.customInstructions = '',
    this.responsePreferences = const ResponsePreferences(),
    this.modelDefaults = const {},
  });

  factory ModelSettings.defaults({String openAiApiKey = ''}) => ModelSettings(
    activeService: ModelService.openAi,
    profiles: <ModelService, ModelConfig>{
      ModelService.openAi: ModelConfig.defaults(
        ModelService.openAi,
        apiKey: openAiApiKey,
      ),
      for (final service in ModelService.values.where(
        (s) => s != ModelService.openAi,
      ))
        service: ModelConfig.defaults(service),
    },
  );

  final Map<ModelPurpose, DefaultModelSelection> modelDefaults;
  final ModelService activeService;
  final Map<ModelService, ModelConfig> profiles;
  final String? systemPrompt;
  final String customInstructions;
  final ResponsePreferences responsePreferences;

  ModelConfig get activeConfig =>
      configFor(ModelPurpose.text) ??
      profiles[activeService]!.copyWith(
        reasoning: profiles[activeService]!.reasoningFor(
          profiles[activeService]!.model,
        ),
      );

  ModelConfig? configFor(ModelPurpose purpose) {
    final selection = modelDefaults[purpose];
    if (selection == null) return null;
    final account = profile(selection.service);
    return ModelConfig(
      service: selection.service,
      apiKey: account.apiKey,
      model: selection.model,
      baseUrl: account.baseUrl,
      reasoning: account.reasoningFor(selection.model),
      details: account.details,
    );
  }

  ModelConfig profile(ModelService service) => profiles[service]!;

  ModelSettings activate(ModelConfig config, {required String? systemPrompt}) =>
      ModelSettings(
        activeService: config.service,
        profiles: <ModelService, ModelConfig>{
          ...profiles,
          config.service: config,
        },
        systemPrompt: systemPrompt,
        customInstructions: customInstructions,
        responsePreferences: responsePreferences,
        modelDefaults: modelDefaults,
      );

  Map<String, Object?> toJson() => <String, Object?>{
    'activeService': activeService.name,
    'modelDefaults': {
      for (final entry in modelDefaults.entries)
        entry.key.name: entry.value.toJson(),
    },
    'systemPrompt': systemPrompt,
    'customInstructions': customInstructions,
    'responsePreferences': responsePreferences.toJson(),
    'profiles': <String, Object?>{
      for (final entry in profiles.entries)
        entry.key.name: entry.value.toJson(),
    },
  };

  factory ModelSettings.fromJson(Map<String, Object?> json) {
    if (json.containsKey('service')) {
      final legacy = ModelConfig.fromJson(json);
      return ModelSettings.defaults().activate(legacy, systemPrompt: null);
    }
    final rawProfiles = (json['profiles']! as Map<Object?, Object?>)
        .cast<String, Object?>();
    final savedServices = rawProfiles.keys.map(ModelService.byName).toList();
    for (var index = 0; index < ModelService.values.length; index++) {
      final service = ModelService.values[index];
      if (!savedServices.contains(service)) {
        savedServices.insert(
          index < savedServices.length ? index : savedServices.length,
          service,
        );
      }
    }
    final purposesByName = {
      for (final purpose in ModelPurpose.values) purpose.name: purpose,
    };
    return ModelSettings(
      modelDefaults: {
        for (final entry in (json['modelDefaults'] as Map? ?? const {}).entries)
          if (purposesByName[entry.key] case final purpose?)
            purpose: DefaultModelSelection.fromJson(
              Map<String, dynamic>.from(entry.value as Map),
            ),
      },
      systemPrompt: json['systemPrompt'] as String?,
      customInstructions: json['customInstructions'] as String? ?? '',
      responsePreferences: json['responsePreferences'] == null
          ? const ResponsePreferences()
          : ResponsePreferences.fromJson(
              Map<String, dynamic>.from(json['responsePreferences'] as Map),
            ),
      activeService: ModelService.byName(json['activeService']! as String),
      profiles: <ModelService, ModelConfig>{
        for (final service in savedServices)
          service: !rawProfiles.containsKey(service.name)
              ? ModelConfig.defaults(service)
              : ModelConfig.fromJson(
                  (rawProfiles[service.name]! as Map<Object?, Object?>)
                      .cast<String, Object?>(),
                ),
      },
    );
  }
}

ModelService _serviceFromStored(String value) => switch (value) {
  'OpenAI' || 'openAi' => ModelService.openAi,
  'DeepSeek' || 'deepSeek' => ModelService.deepSeek,
  'qwen' => ModelService.qwen,
  'kimi' => ModelService.kimi,
  'glm' => ModelService.glm,
  'openRouter' => ModelService.openRouter,
  'dmxapi' => ModelService.dmxapi,
  _ => ModelService.byName(value),
};

class ModelRequest {
  const ModelRequest({
    required this.messages,
    required this.tools,
    required this.capabilities,
    this.continuationToken,
    this.contextSummary,
    this.personalContext = '',
    this.onContextSummary,
    this.onCompactionChanged,
    this.onTextChanged,
    this.onReasoningChanged,
    this.onProcessingStarted,
    this.onReconnect,
    this.onMessageStarted,
    this.toolResults = const <ToolResult>[],
    this.userUpdates = const <String>[],
  });

  final List<AgentMessage> messages;
  final List<ToolDefinition> tools;
  final List<Capability> capabilities;
  final String? continuationToken;
  final ContextSummary? contextSummary;
  final String personalContext;
  final Future<void> Function(ContextSummary)? onContextSummary;
  final void Function(bool)? onCompactionChanged;
  final List<ToolResult> toolResults;
  final List<String> userUpdates;
  final void Function(String text)? onTextChanged;
  final void Function(String text)? onReasoningChanged;
  final void Function()? onProcessingStarted;
  final void Function(int attempt)? onReconnect;
  final void Function(int index)? onMessageStarted;
}

class ModelTurn {
  const ModelTurn({
    required this.continuationToken,
    required this.toolCalls,
    this.text,
    required this.response,
    required this.requestInput,
  });

  final List<Map<String, Object?>> requestInput;
  final Map<String, Object?> response;
  final String continuationToken;
  final String? text;
  final List<ToolCall> toolCalls;
}

abstract interface class ModelProvider {
  Future<ModelTurn> respond(ModelRequest request);

  Future<void> cancel();
}

class ModelProviderException implements Exception {
  const ModelProviderException(this.message, {this.detail, this.statusCode});

  final String message;
  final String? detail;
  final int? statusCode;

  String get displayMessage {
    var reason = detail?.trim() ?? '';
    if (reason.isNotEmpty) {
      try {
        final decoded = jsonDecode(reason);
        final error = decoded is Map ? decoded['error'] ?? decoded : decoded;
        if (error is Map) {
          final text =
              error['message'] ?? error['detail'] ?? error['description'];
          final code = error['code'];
          reason = [
            if (text != null) '$text',
            if (code != null) '错误码：$code',
          ].join('\n');
          if (reason.isEmpty) reason = detail!.trim();
        } else if (error is String) {
          reason = error;
        }
      } on FormatException {
        // Non-JSON error bodies are returned by some gateways.
      }
    }
    final heading = statusCode == null ? message : '$message（HTTP $statusCode）';
    return reason.isEmpty || reason == message ? heading : '$heading\n$reason';
  }

  @override
  String toString() => displayMessage;
}

class ModelConnectionInterrupted extends ModelProviderException {
  const ModelConnectionInterrupted(super.message, {super.detail});
}
