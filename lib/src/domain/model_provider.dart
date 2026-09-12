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
  const ModelSettings({required this.activeService, required this.profiles});

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

  ModelConfig get activeConfig => profiles[activeService]!;

  ModelConfig profile(ModelService service) => profiles[service]!;

  ModelSettings activate(ModelConfig config) => ModelSettings(
    activeService: config.service,
    profiles: <ModelService, ModelConfig>{...profiles, config.service: config},
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'activeService': activeService.name,
    'profiles': <String, Object?>{
      for (final entry in profiles.entries)
        entry.key.name: entry.value.toJson(),
    },
  };

  factory ModelSettings.fromJson(Map<String, Object?> json) {
    if (json.containsKey('service')) {
      final legacy = ModelConfig.fromJson(json);
      return ModelSettings.defaults().activate(legacy);
    }
    final rawProfiles = (json['profiles']! as Map<Object?, Object?>)
        .cast<String, Object?>();
    return ModelSettings(
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
    this.onContextSummary,
    this.onTextChanged,
    this.toolResults = const <ToolResult>[],
  });

  final List<AgentMessage> messages;
  final List<ToolDefinition> tools;
  final List<Capability> capabilities;
  final String? continuationToken;
  final ContextSummary? contextSummary;
  final Future<void> Function(ContextSummary)? onContextSummary;
  final List<ToolResult> toolResults;
  final void Function(String text)? onTextChanged;
}

class ModelTurn {
  const ModelTurn({
    required this.continuationToken,
    required this.toolCalls,
    this.text,
  });

  final String continuationToken;
  final String? text;
  final List<ToolCall> toolCalls;
}

abstract interface class ModelProvider {
  Future<ModelTurn> respond(ModelRequest request);

  Future<void> cancel();
}

class ModelProviderException implements Exception {
  const ModelProviderException(this.message, {this.detail});

  final String message;
  final String? detail;

  @override
  String toString() => message;
}
