import 'model_provider.dart';

typedef AvailableMusicModel = ({ModelConfig config, String model});

extension MusicModelSelection on ModelSettings {
  AvailableMusicModel? get firstAvailableMusicModel {
    final selected = modelDefaults[ModelPurpose.musicGeneration];
    if (selected != null) {
      final config = profile(selected.service);
      final available = config.protocol.modelCatalog.any(
        (model) => model.id == selected.model,
      );
      if (config.isConfigured &&
          available &&
          (config.autoSyncModels ||
              config.savedModels.contains(selected.model))) {
        return (config: config, model: selected.model);
      }
    }
    for (final config in profiles.values) {
      if (!config.protocol.defaultModelPurposes.contains(
            ModelPurpose.musicGeneration,
          ) ||
          !config.isConfigured) {
        continue;
      }
      final available = [
        for (final model in config.protocol.modelCatalog)
          if (config.autoSyncModels || config.savedModels.contains(model.id))
            model.id,
      ];
      if (available.isEmpty) continue;
      return (
        config: config,
        model: available.contains(config.model)
            ? config.model
            : available.first,
      );
    }
    return null;
  }
}
