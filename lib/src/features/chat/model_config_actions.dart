part of 'chat_controller.dart';

extension ModelConfigActions on ChatController {
  Future<void> saveConfig(
    ModelConfig newConfig, {
    String? senderId,
    List<ModelConfig> profiles = const [],
    required ModelService defaultService,
  }) async {
    final nextSettings = ModelSettings(
      activeService: defaultService,
      profiles: {
        ...modelSettings.profiles,
        for (final config in profiles) config.service: config,
        newConfig.service: newConfig,
      },
      systemPrompt: modelSettings.systemPrompt,
      customInstructions: modelSettings.customInstructions,
      responsePreferences: modelSettings.responsePreferences,
    );
    await _platform.saveModelSettings(nextSettings);
    modelSettings = nextSettings;
    final defaultConfig = nextSettings.activeConfig;
    groupStore.defaultSelection = AiModelSelection(
      provider: defaultConfig.service,
      model: defaultConfig.model,
      baseUrl: defaultConfig.baseUrl,
    );
    if (senderId != null) {
      final ai = await groupStore.loadAi(senderId);
      await saveAi(
        ai.copyWith(
          modelSelection: AiModelSelection(
            provider: newConfig.service,
            model: newConfig.model,
            baseUrl: newConfig.baseUrl,
          ),
        ),
      );
    }
    _conversationChanged();
  }
}
