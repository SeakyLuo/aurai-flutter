import 'package:collection/collection.dart';
import '../../domain/model_provider.dart';
import 'chat_controller.dart';

/// Shared by the provider form and its nested editors; never writes storage.
class ProviderSettingsDraft {
  ProviderSettingsDraft(this.config);
  ModelConfig config;

  bool differsFrom(ModelConfig saved) => !const DeepCollectionEquality().equals(
    [
      config.details?.requestAdapters.map((k, v) => MapEntry(k, v.toJson())) ??
          {},
      config.details?.modelContextOverrides.map(
            (k, v) => MapEntry(k, v.toJson()),
          ) ??
          {},
      config.details?.modelPurposes ?? {},
      config.details?.modelReasoning ?? {},
      config.details?.balance?.toJson(),
      config.speechApi?.toJson(),
      config.details?.speechApiKey ?? '',
      config.details?.modelCatalog ?? const [],
      config.details?.modelApiNames ?? const {},
    ],
    [
      saved.details?.requestAdapters.map((k, v) => MapEntry(k, v.toJson())) ??
          {},
      saved.details?.modelContextOverrides.map(
            (k, v) => MapEntry(k, v.toJson()),
          ) ??
          {},
      saved.details?.modelPurposes ?? {},
      saved.details?.modelReasoning ?? {},
      saved.details?.balance?.toJson(),
      saved.speechApi?.toJson(),
      saved.details?.speechApiKey ?? '',
      saved.details?.modelCatalog ?? const [],
      saved.details?.modelApiNames ?? const {},
    ],
  );

  void updateDetails(Map<String, Object?> fields) {
    config = config.copyWith(
      details: ProviderDetails.fromJson({
        ...config.details!.toJson(),
        ...fields,
      }),
    );
  }
}

Future<void> saveProviderEditorConfig(
  ChatController controller,
  ProviderSettingsDraft? draft,
  ModelConfig config, {
  required ModelService defaultService,
}) async {
  if (draft != null) {
    draft.config = config;
  } else {
    await controller.saveConfig(config, defaultService: defaultService);
  }
}
