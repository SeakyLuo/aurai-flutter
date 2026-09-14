import 'dart:convert';
import 'response_preferences.dart';
export 'response_preferences.dart';
import 'agent_models.dart';
import 'context_summary.dart';
import 'capability.dart';
import 'tool_models.dart';

enum ModelService { openAi, deepSeek }

extension ModelServiceDetails on ModelService {
  String get label => switch (this) {
    ModelService.openAi => 'OpenAI',
    ModelService.deepSeek => 'DeepSeek',
  };

  String get defaultModel => switch (this) {
    ModelService.openAi => 'gpt-5.4-mini',
    ModelService.deepSeek => 'deepseek-v4-flash',
  };

  String get defaultBaseUrl => switch (this) {
    ModelService.openAi => 'https://api.openai.com/v1',
    ModelService.deepSeek => 'https://api.deepseek.com',
  };
}

class ModelConfig {
  const ModelConfig({
    required this.apiKey,
    this.service = ModelService.openAi,
    required this.model,
    required this.baseUrl,
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

  bool get isConfigured => apiKey.isNotEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
    'service': service.name,
    'apiKey': apiKey,
    'model': model,
    'baseUrl': baseUrl,
  };

  factory ModelConfig.fromJson(Map<String, Object?> json) => ModelConfig(
    service: _serviceFromStored(json['service']! as String),
    apiKey: json['apiKey']! as String,
    model: json['model']! as String,
    baseUrl: json['baseUrl']! as String,
  );
}

class ModelSettings {
  const ModelSettings({
    required this.activeService,
    required this.profiles,
    this.systemPrompt,
    this.customInstructions = '',
    this.responsePreferences = const ResponsePreferences(),
  });

  factory ModelSettings.defaults({String openAiApiKey = ''}) => ModelSettings(
    activeService: ModelService.openAi,
    profiles: <ModelService, ModelConfig>{
      ModelService.openAi: ModelConfig.defaults(
        ModelService.openAi,
        apiKey: openAiApiKey,
      ),
      ModelService.deepSeek: ModelConfig.defaults(ModelService.deepSeek),
    },
  );

  final ModelService activeService;
  final Map<ModelService, ModelConfig> profiles;
  final String? systemPrompt;
  final String customInstructions;
  final ResponsePreferences responsePreferences;

  ModelConfig get activeConfig => profiles[activeService]!;

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
      );

  Map<String, Object?> toJson() => <String, Object?>{
    'activeService': activeService.name,
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
    return ModelSettings(
      systemPrompt: json['systemPrompt'] as String?,
      customInstructions: json['customInstructions'] as String? ?? '',
      responsePreferences: json['responsePreferences'] == null
          ? const ResponsePreferences()
          : ResponsePreferences.fromJson(
              Map<String, dynamic>.from(json['responsePreferences'] as Map),
            ),
      activeService: ModelService.values.byName(
        json['activeService']! as String,
      ),
      profiles: <ModelService, ModelConfig>{
        for (final service in ModelService.values)
          service: ModelConfig.fromJson(
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
  _ => throw FormatException('Unknown model service: $value'),
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
    this.onTextChanged,
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
  final List<ToolResult> toolResults;
  final List<String> userUpdates;
  final void Function(String text)? onTextChanged;
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
