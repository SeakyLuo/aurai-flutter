part of 'chat_controller.dart';

class UsedModelSelection {
  const UsedModelSelection({required this.model, required this.impact});

  final DefaultModelSelection model;
  final ModelReplacementImpact impact;
}

class ModelReplacementTarget {
  const ModelReplacementTarget({
    required this.model,
    required this.supportedPurposes,
    required this.supportsText,
    this.imageGeneration,
  });

  final DefaultModelSelection model;
  final Set<ModelPurpose> supportedPurposes;
  final bool supportsText;
  final ImageGenerationModel? imageGeneration;
}

class ModelReplacementImpact {
  const ModelReplacementImpact({required this.aiCount, required this.purposes});

  final int aiCount;
  final Set<ModelPurpose> purposes;
  bool get hasChanges => aiCount > 0 || purposes.isNotEmpty;
}

extension ModelConfigActions on ChatController {
  Future<T> _serializeModelSettings<T>(Future<T> Function() operation) {
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

  Future<List<UsedModelSelection>> usedModels() async {
    final rows = await _store.database.query(
      'ai_profiles',
      columns: ['provider', 'model', 'COUNT(*) AS count'],
      where: 'provider IS NOT NULL',
      groupBy: 'provider, model',
    );
    final selections = <String, DefaultModelSelection>{};
    final aiCounts = <String, int>{};
    final purposes = <String, Set<ModelPurpose>>{};
    String key(ModelService service, String model) => '${service.name}\n$model';
    void add(
      ModelService service,
      String model, {
      required String name,
      int aiCount = 0,
      ModelPurpose? purpose,
    }) {
      final id = key(service, model);
      selections[id] = DefaultModelSelection(
        service: service,
        model: model,
        name: name,
      );
      aiCounts[id] = (aiCounts[id] ?? 0) + aiCount;
      if (purpose != null) purposes.putIfAbsent(id, () => {}).add(purpose);
    }

    for (final row in rows) {
      add(
        ModelService.byName(row['provider']! as String),
        row['model']! as String,
        name: modelDisplayName(row['model']! as String),
        aiCount: row['count']! as int,
      );
    }
    for (final entry in _effectiveModelSelections().entries) {
      add(
        entry.value.service,
        entry.value.model,
        name: entry.value.name,
        purpose: entry.key,
      );
    }
    final result = [
      for (final entry in selections.entries)
        UsedModelSelection(
          model: entry.value,
          impact: ModelReplacementImpact(
            aiCount: aiCounts[entry.key] ?? 0,
            purposes: purposes[entry.key] ?? const {},
          ),
        ),
    ];
    result.sort((a, b) {
      final provider = modelSettings
          .profile(a.model.service)
          .displayName
          .compareTo(modelSettings.profile(b.model.service).displayName);
      return provider != 0 ? provider : a.model.name.compareTo(b.model.name);
    });
    return result;
  }

  Map<ModelPurpose, DefaultModelSelection> _effectiveModelSelections() {
    final active = modelSettings.activeConfig;
    return {
      ModelPurpose.text: DefaultModelSelection(
        service: active.service,
        model: active.model,
        name: modelDisplayName(active.model),
      ),
      for (final purpose in [
        ModelPurpose.imageUnderstanding,
        ModelPurpose.videoUnderstanding,
        ModelPurpose.videoGeneration,
      ])
        if (modelSettings.modelDefaults[purpose] case final selection?)
          purpose: selection,
      if (imageGeneration case final selection?)
        ModelPurpose.imageGeneration: DefaultModelSelection(
          service: selection.service,
          model: selection.model.id,
          name: selection.model.name,
        ),
    };
  }

  Future<ModelReplacementImpact> modelReplacementImpact({
    DefaultModelSelection? from,
    DefaultModelSelection? to,
  }) async {
    if (to != null && _sameModelSelection(from, to)) {
      return const ModelReplacementImpact(aiCount: 0, purposes: {});
    }
    final rows = await _store.database.query(
      'ai_profiles',
      columns: ['COUNT(*) AS count'],
      where: from == null
          ? to == null
                ? 'provider IS NOT NULL'
                : 'provider IS NOT NULL AND (provider != ? OR model != ?)'
          : 'provider = ? AND model = ?',
      whereArgs: from == null
          ? to == null
                ? null
                : [to.service.name, to.model]
          : [from.service.name, from.model],
    );
    final purposes = <ModelPurpose>{};
    for (final entry in _effectiveModelSelections().entries) {
      if ((from == null || _sameModelSelection(from, entry.value)) &&
          (to == null || !_sameModelSelection(entry.value, to))) {
        purposes.add(entry.key);
      }
    }
    return ModelReplacementImpact(
      aiCount: rows.single['count']! as int,
      purposes: purposes,
    );
  }

  Future<ModelReplacementImpact> replaceModels({
    DefaultModelSelection? from,
    required ModelReplacementTarget to,
  }) => _serializeModelSettings(() async {
    if (_sameModelSelection(from, to.model)) throw StateError('新旧模型不能相同');
    final targetAccount = modelSettings.profile(to.model.service);
    if (!targetAccount.isConfigured) throw StateError('请先配置新模型的供应商');
    final impact = await modelReplacementImpact(from: from, to: to.model);
    if (!impact.hasChanges) throw StateError('当前没有使用该模型的 AI 或默认设置');
    if (impact.aiCount > 0 && !to.supportsText) throw StateError('新模型不支持文字回复');
    final unsupported = impact.purposes.difference(to.supportedPurposes);
    if (unsupported.isNotEmpty)
      throw StateError(
        '新模型不支持${unsupported.first.label.replaceFirst('模型', '')}',
      );

    final defaults = {...modelSettings.modelDefaults};
    for (final purpose in impact.purposes) {
      if (purpose != ModelPurpose.imageGeneration) defaults[purpose] = to.model;
    }
    final nextSettings = ModelSettings(
      activeService: impact.purposes.contains(ModelPurpose.text)
          ? to.model.service
          : modelSettings.activeService,
      profiles: modelSettings.profiles,
      systemPrompt: modelSettings.systemPrompt,
      customInstructions: modelSettings.customInstructions,
      responsePreferences: modelSettings.responsePreferences,
      modelDefaults: defaults,
    );
    final encrypted = await _platform.encryptModelSettings(nextSettings);
    final nextImageGeneration =
        impact.purposes.contains(ModelPurpose.imageGeneration)
        ? ImageGenerationConfig(
            service: to.model.service,
            model: to.imageGeneration!,
          )
        : imageGeneration;
    final now = DateTime.now().microsecondsSinceEpoch;
    final affected = await _store.database.transaction((txn) async {
      final rows = await txn.query(
        'ai_profiles',
        columns: ['sender_id', 'preferences'],
        where: from == null
            ? 'provider IS NOT NULL AND (provider != ? OR model != ?)'
            : 'provider = ? AND model = ?',
        whereArgs: from == null
            ? [to.model.service.name, to.model.model]
            : [from.service.name, from.model],
      );
      await txn.update(
        'ai_profiles',
        {
          'provider': to.model.service.name,
          'model': to.model.model,
          'base_url': targetAccount.baseUrl,
          'updated_at': now,
        },
        where: from == null
            ? 'provider IS NOT NULL AND (provider != ? OR model != ?)'
            : 'provider = ? AND model = ?',
        whereArgs: from == null
            ? [to.model.service.name, to.model.model]
            : [from.service.name, from.model],
      );
      if (impact.purposes.any(
        (purpose) => purpose != ModelPurpose.imageGeneration,
      )) {
        await txn.rawInsert(
          'INSERT INTO app_state(key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value',
          ['encrypted_model_config', encrypted],
        );
      }
      if (impact.purposes.contains(ModelPurpose.imageGeneration)) {
        await txn.rawInsert(
          'INSERT INTO app_state(key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value',
          ['image_generation', jsonEncode(nextImageGeneration!.toJson())],
        );
      }
      return rows;
    });

    modelSettings = nextSettings;
    imageGeneration = nextImageGeneration;
    final targetSelection = AiModelSelection(
      provider: to.model.service,
      model: to.model.model,
      baseUrl: targetAccount.baseUrl,
    );
    final affectedIds = {
      for (final row in affected) row['sender_id']! as String,
    };
    final reasoningById = {
      for (final row in affected)
        row['sender_id']! as String: AiPreferences.fromJson(
          jsonDecode(row['preferences']! as String) as Map<String, dynamic>,
        ).reasoning,
    };
    if (_activeAi case final active?
        when affectedIds.contains(active.sender.id)) {
      _activeAi = active.copyWith(modelSelection: targetSelection);
    }
    for (final state in {_execution, ..._executionStates.values}) {
      for (final id in state.groupReplies.keys.toList()) {
        if (!affectedIds.contains(id)) continue;
        final profile = state.groupReplies[id]!.profile.copyWith(
          modelSelection: targetSelection,
        );
        state.groupReplies[id] = _groupReplyContext(profile);
      }
    }
    for (final store in [memory, ..._aiMemories.values]) {
      final reasoning = reasoningById[store.ownerId];
      if (reasoning == null) continue;
      store.modelConfig = () => ModelConfig(
        service: to.model.service,
        apiKey: targetAccount.apiKey,
        model: to.model.model,
        baseUrl: targetAccount.baseUrl,
        details: targetAccount.details,
        reasoning: reasoning == ModelReasoning.inherit
            ? targetAccount.reasoning
            : reasoning,
      );
    }
    final defaultConfig = nextSettings.activeConfig;
    groupStore.defaultSelection = AiModelSelection(
      provider: defaultConfig.service,
      model: defaultConfig.model,
      baseUrl: defaultConfig.baseUrl,
    );
    _conversationChanged();
    return impact;
  });

  bool _sameModelSelection(
    DefaultModelSelection? first,
    DefaultModelSelection second,
  ) =>
      first != null &&
      first.service == second.service &&
      first.model == second.model;

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
