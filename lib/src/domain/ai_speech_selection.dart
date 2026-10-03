import 'model_provider.dart';

class AiSpeechSelection {
  const AiSpeechSelection({
    required this.service,
    required this.model,
    required this.voice,
  });
  final ModelService service;
  final String model, voice;
  Map<String, Object?> toJson() => {
    'service': service.name,
    'model': model,
    'voice': voice,
  };
  factory AiSpeechSelection.fromJson(Map<String, dynamic> json) =>
      AiSpeechSelection(
        service: ModelService.byName(json['service'] as String),
        model: json['model'] as String,
        voice: json['voice'] as String,
      );
}
