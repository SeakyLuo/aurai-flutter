import 'model_provider.dart';

class ImageGenerationModel {
  const ImageGenerationModel({
    required this.id,
    required this.name,
    required this.supportsReference,
    required this.aspectRatios,
    this.outputFormat,
  });

  final String id;
  final String name;
  final bool supportsReference;
  final List<String> aspectRatios;
  final String? outputFormat;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'supportsReference': supportsReference,
    'aspectRatios': aspectRatios,
    'outputFormat': outputFormat,
  };

  factory ImageGenerationModel.fromJson(Map<String, dynamic> json) =>
      ImageGenerationModel(
        id: json['id'] as String,
        name: json['name'] as String,
        supportsReference: json['supportsReference'] as bool,
        aspectRatios: List<String>.from(json['aspectRatios'] as List),
        outputFormat: json['outputFormat'] as String?,
      );
}

class ImageGenerationConfig {
  const ImageGenerationConfig({required this.service, required this.model});

  final ModelService service;
  final ImageGenerationModel model;

  Map<String, Object?> toJson() => {
    'service': service.name,
    'model': model.toJson(),
  };

  factory ImageGenerationConfig.fromJson(Map<String, dynamic> json) =>
      ImageGenerationConfig(
        service: ModelService.values.byName(json['service'] as String),
        model: ImageGenerationModel.fromJson(
          json['model'] as Map<String, dynamic>,
        ),
      );
}
