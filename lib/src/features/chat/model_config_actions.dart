part of 'chat_controller.dart';

extension ModelConfigActions on ChatController {
  Future<void> _serializeModelSettings(Future<void> Function() operation) {
    final result = _modelSettingsWrite.then((_) => operation());
    _modelSettingsWrite = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  Future<void> reorderModelProviders(
    List<ModelService> order,
  ) => _serializeModelSettings(() async {
    final next = ModelSettings(
      activeService: modelSettings.activeService,
      profiles: {
        for (final service in order) service: modelSettings.profile(service),
      },
      systemPrompt: modelSettings.systemPrompt,
      customInstructions: modelSettings.customInstructions,
      responsePreferences: modelSettings.responsePreferences,
      modelDefaults: modelSettings.modelDefaults,
    );
    final encrypted = await _platform.encryptModelSettings(next);
    await _store.database.rawInsert(
      'INSERT INTO app_state(key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value',
      ['encrypted_model_config', encrypted],
    );
    modelSettings = next;
    _conversationChanged();
  });

  Future<void> saveDefaultModel(
    ModelPurpose purpose,
    DefaultModelSelection selection,
  ) => _serializeModelSettings(() => _saveDefaultModel(purpose, selection));

  Future<void> saveConfig(
    ModelConfig newConfig, {
    String? senderId,
    List<ModelConfig> profiles = const [],
    required ModelService defaultService,
  }) => _serializeModelSettings(
    () => _saveConfig(
      newConfig,
      senderId: senderId,
      profiles: profiles,
      defaultService: defaultService,
    ),
  );

  Future<void> _saveDefaultModel(
    ModelPurpose purpose,
    DefaultModelSelection selection,
  ) async {
    final next = ModelSettings(
      activeService: purpose == ModelPurpose.text
          ? selection.service
          : modelSettings.activeService,
      profiles: modelSettings.profiles,
      systemPrompt: modelSettings.systemPrompt,
      customInstructions: modelSettings.customInstructions,
      responsePreferences: modelSettings.responsePreferences,
      modelDefaults: {...modelSettings.modelDefaults, purpose: selection},
    );
    final encrypted = await _platform.encryptModelSettings(next);
    await _store.database.rawInsert(
      'INSERT INTO app_state(key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value',
      ['encrypted_model_config', encrypted],
    );
    modelSettings = next;
    final config = next.activeConfig;
    groupStore.defaultSelection = AiModelSelection(
      provider: config.service,
      model: config.model,
      baseUrl: config.baseUrl,
    );
    _conversationChanged();
  }

  Future<void> _saveConfig(
    ModelConfig newConfig, {
    String? senderId,
    List<ModelConfig> profiles = const [],
    required ModelService defaultService,
  }) async {
    newConfig = newConfig.copyWith(
      details:
          newConfig.details ??
          modelSettings.profiles[newConfig.service]?.details,
    );
    if (newConfig.details != null) {
      validateProviderDetails(newConfig.details!, newConfig.baseUrl);
      if (modelSettings.profiles.values.any(
        (other) =>
            other.service != newConfig.service &&
            other.displayName.toLowerCase() ==
                newConfig.displayName.toLowerCase(),
      )) {
        throw ArgumentError('该供应商名称已存在');
      }
    }
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
      modelDefaults: modelSettings.modelDefaults,
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
        final old = AiProfile.fromRows(
          MessageSender.fromRow(senders.single),
          profiles.single,
        );
        updated = old.copyWith(
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
    _refreshGroupModelConfigs();
    _conversationChanged();
  }
}
