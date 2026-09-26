import '../domain/model_provider.dart';
import 'openrouter_models.dart';

Set<ModelPurpose> modelPurposesFor(ModelConfig config, String model) {
  final configured = config.details?.modelPurposes[model];
  if (configured != null) return configured;
  final name = model.split('/').last;
  if (name.startsWith('gpt-image-') || name == 'chatgpt-image-latest') {
    return {ModelPurpose.imageGeneration};
  }
  if (config.service.staticImageModelIds.contains(model)) {
    return {ModelPurpose.imageGeneration};
  }
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
