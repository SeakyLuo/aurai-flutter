import 'model_provider.dart';

enum ModelPurpose {
  text('默认文本模型'),
  imageGeneration('图片生成模型'),
  videoGeneration('视频生成模型');

  const ModelPurpose(this.label);
  final String label;
}

class DefaultModelSelection {
  const DefaultModelSelection({
    required this.service,
    required this.model,
    required this.name,
  });
  final ModelService service;
  final String model, name;

  Map<String, Object?> toJson() => {
    'service': service.name,
    'model': model,
    'name': name,
  };

  factory DefaultModelSelection.fromJson(Map<String, dynamic> json) =>
      DefaultModelSelection(
        service: ModelService.byName(json['service'] as String),
        model: json['model'] as String,
        name: json['name'] as String,
      );
}
