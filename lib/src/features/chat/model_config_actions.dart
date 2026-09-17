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
    final encrypted = await _platform.encryptModelSettings(nextSettings);
    final updatedAi = await _store.database.transaction((txn) async {
      AiProfile? updated;
      if (senderId != null) {
        final profiles = await txn.query(
          'ai_profiles',
          where: 'sender_id = ?',
          whereArgs: [senderId],
        );
        if (profiles.isEmpty) throw StateError('AI 已不存在');
        final senders = await txn.query(
          'message_senders',
          where: 'id = ?',
          whereArgs: [senderId],
        );
        updated =
            AiProfile.fromRows(
              MessageSender.fromRow(senders.single),
              profiles.single,
            ).copyWith(
              modelSelection: AiModelSelection(
                provider: newConfig.service,
                model: newConfig.model,
                baseUrl: newConfig.baseUrl,
              ),
            );
        await txn.update(
          'ai_profiles',
          {
            'provider': newConfig.service.name,
            'model': newConfig.model,
            'base_url': newConfig.baseUrl,
            'updated_at': updated.updatedAt.microsecondsSinceEpoch,
          },
          where: 'sender_id = ?',
          whereArgs: [senderId],
        );
      }
      await txn.rawInsert(
        'INSERT INTO app_state(key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value',
        ['encrypted_model_config', encrypted],
      );
      return updated;
    });
    modelSettings = nextSettings;
    final defaultConfig = nextSettings.activeConfig;
    groupStore.defaultSelection = AiModelSelection(
      provider: defaultConfig.service,
      model: defaultConfig.model,
      baseUrl: defaultConfig.baseUrl,
    );
    if (updatedAi != null) _applySavedAi(updatedAi);
    _conversationChanged();
  }
}
