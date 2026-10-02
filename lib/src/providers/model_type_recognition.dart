import '../domain/model_provider.dart';

abstract final class ModelTypeRecognition {
  static const defaults = <String, ModelPurpose>{
    'text': ModelPurpose.text,
    'chat': ModelPurpose.text,
    'completion': ModelPurpose.text,
    'llm': ModelPurpose.text,
    'image': ModelPurpose.imageGeneration,
    'images': ModelPurpose.imageGeneration,
    'image_generation': ModelPurpose.imageGeneration,
    'video': ModelPurpose.videoGeneration,
    'videos': ModelPurpose.videoGeneration,
    'video_generation': ModelPurpose.videoGeneration,
    'music': ModelPurpose.musicGeneration,
    'audio': ModelPurpose.musicGeneration,
    'music_generation': ModelPurpose.musicGeneration,
    'audio_generation': ModelPurpose.musicGeneration,
  };

  static Set<ModelPurpose> purposes(
    Map<String, dynamic> model,
    String configuredPath,
    Map<String, ModelPurpose> mappings,
  ) {
    if (configuredPath.isEmpty && read(model, '').path == null) {
      final endpoints = model['supported_endpoint_types'] as List?;
      if (endpoints != null) {
        final media = {
          for (final endpoint in endpoints)
            if (defaults['$endpoint'.replaceAll('-', '_')] case final purpose?)
              purpose,
        };
        if (media.isNotEmpty) return media;
        final id = (model['id'] as String).split('/').last;
        if (id.startsWith('gemini-') && id.contains('-image')) {
          return {ModelPurpose.imageGeneration};
        }
        if (endpoints.any(
          (endpoint) => const {
            'openai',
            'anthropic',
            'gemini',
            'openai-response',
          }.contains(endpoint),
        )) {
          return {ModelPurpose.text};
        }
      }
    }
    final value = read(model, configuredPath).value;
    final values = value is List ? value : [if (value != null) value];
    final rules = mappings.isEmpty ? defaults : mappings;
    return {
      for (final item in values)
        if ((rules['$item'] ??
                rules['$item'.trim().toLowerCase().replaceAll('-', '_')])
            case final purpose?)
          purpose,
    };
  }

  static ({String? path, Object? value}) read(
    Map<String, dynamic> model,
    String configuredPath,
  ) {
    final paths = configuredPath.isEmpty
        ? const [
            'architecture.output_modalities',
            'output_modalities',
            'modalities',
            'type',
          ]
        : [configuredPath];
    Object? value;
    for (final path in paths) {
      value = valueAt(model, path);
      if (value != null) return (path: path, value: value);
    }
    return (path: null, value: null);
  }

  static Object? valueAt(Map<String, dynamic> source, String path) {
    Object? value = source;
    for (final segment in path.split('.')) {
      if (value is! Map || !value.containsKey(segment)) return null;
      value = value[segment];
    }
    return value;
  }

  static ModelPurpose? builtin(String value) => switch (value
      .trim()
      .toLowerCase()
      .replaceAll('-', '_')) {
    'text' || 'chat' || 'completion' || 'llm' => ModelPurpose.text,
    'image' || 'images' || 'image_generation' => ModelPurpose.imageGeneration,
    'video' || 'videos' || 'video_generation' => ModelPurpose.videoGeneration,
    'music' ||
    'audio' ||
    'music_generation' ||
    'audio_generation' => ModelPurpose.musicGeneration,
    _ => null,
  };
}
