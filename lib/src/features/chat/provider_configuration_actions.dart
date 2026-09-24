part of 'chat_controller.dart';

extension ProviderConfigurationActions on ChatController {
  Future<void> removeProviderConfiguration(
    ModelService service, {
    required bool delete,
  }) => _serializeModelSettings(() async {
    final old = modelSettings.profile(service);
    if (!delete) {
      await _saveConfig(
        ModelConfig(
          service: service,
          apiKey: '',
          model: old.model,
          baseUrl: old.baseUrl,
          reasoning: old.reasoning,
        ),
        defaultService: modelSettings.activeService,
      );
      return;
    }
    if (!service.isCustom) throw StateError('内置供应商不能删除，可以清除密钥');
    if (modelSettings.activeService == service ||
        modelSettings.modelDefaults.values.any(
          (value) => value.service == service,
        ) ||
        imageGeneration?.service == service) {
      throw StateError('该供应商仍用于默认模型，请先在模型设置中更换供应商');
    }
    final next = ModelSettings(
      activeService: modelSettings.activeService,
      profiles: {...modelSettings.profiles}..remove(service),
      systemPrompt: modelSettings.systemPrompt,
      customInstructions: modelSettings.customInstructions,
      responsePreferences: modelSettings.responsePreferences,
      modelDefaults: modelSettings.modelDefaults,
    );
    final encoded = jsonEncode(next.toJson());
    await _store.database.transaction((txn) async {
      final profiles = await txn.query(
        'ai_profiles',
        columns: ['sender_id'],
        where: 'provider = ?',
        whereArgs: [service.name],
        limit: 1,
      );
      if (profiles.isNotEmpty)
        throw StateError('还有 AI 使用该供应商，请先在 AI 的模型设置中更换供应商');
      final runs = await txn.query(
        'agent_runs',
        columns: ['id'],
        where: 'provider = ? AND status = ?',
        whereArgs: [service.name, 'running'],
        limit: 1,
      );
      if (runs.isNotEmpty) throw StateError('该供应商仍有任务执行中，请结束任务后再删除');
      await txn.rawInsert(
        'INSERT INTO app_state(key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value',
        ['model_config_json', encoded],
      );
    });
    modelSettings = next;
    _conversationChanged();
  });

  Future<void> addModelProvider({
    required String name,
    required String baseUrl,
    required String apiKey,
    String website = '',
    ProviderProtocol protocol = ProviderProtocol.openaiChatCompletions,
    List<String> models = const [],
    bool autoSyncModels = true,
    String model = '',
  }) => _serializeModelSettings(() async {
    final details = ProviderDetails(
      name: name.trim(),
      website: website.trim(),
      protocol: protocol,
      models: models,
      autoSyncModels: autoSyncModels,
    );
    validateProviderDetails(details, baseUrl);
    await _saveConfig(
      ModelConfig(
        service: ModelService.create(),
        apiKey: apiKey.trim(),
        model: model,
        baseUrl: baseUrl,
        details: details,
      ),
      defaultService: modelSettings.activeService,
    );
  });

  Map<String, Object?> _providerSummary(ModelConfig config) => {
    'provider': config.service.name,
    'name': config.displayName,
    'website': config.website,
    'models': config.savedModels,
    'baseUrl': config.baseUrl,
    'model': config.model,
    'configured': config.isConfigured,
    'protocol': config.protocol.name,
  };

  Future<Map<String, Object?>> _configureProvider(
    String operation,
    Map<String, Object?> args,
    ValueNotifier<bool> cancelled,
  ) async {
    if (operation == 'listModelProviders') {
      return {
        'providers': modelSettings.profiles.values
            .map(_providerSummary)
            .toList(),
      };
    }
    if (operation == 'configureModelProvider') {
      final name = (args['name'] as String).trim();
      final url = (args['baseUrl'] as String).trim();
      late ModelConfig saved;
      await _serializeModelSettings(() async {
        if (cancelled.value) throw StateError('操作已取消');
        final service = args['provider'] != null
            ? ModelService.byName(args['provider'] as String)
            : modelSettings.profiles.values
                      .where(
                        (p) =>
                            p.displayName.toLowerCase() == name.toLowerCase(),
                      )
                      .firstOrNull
                      ?.service ??
                  ModelService.create();
        final old = args['provider'] != null
            ? modelSettings.profile(service)
            : modelSettings.profiles[service];
        final details = ProviderDetails(
          requestAdapters: old?.details?.requestAdapters ?? const {},
          name: name,
          website: (args['website'] as String? ?? old?.website ?? '').trim(),
          protocol: ProviderProtocol.values.byName(args['protocol'] as String),
          autoSyncModels:
              args['autoSyncModels'] as bool? ?? old?.autoSyncModels ?? true,
          models: args['models'] == null
              ? old?.savedModels ?? const []
              : List<String>.from(args['models'] as List),
        );
        validateProviderDetails(details, url);
        saved = ModelConfig(
          service: service,
          apiKey: old?.baseUrl == url ? old!.apiKey : '',
          model: (args['model'] as String).trim(),
          baseUrl: url,
          reasoning: old?.reasoning ?? ModelReasoning.automatic,
          details: details,
        );
        await _saveConfig(saved, defaultService: modelSettings.activeService);
      });
      return {..._providerSummary(saved), 'saved': true};
    }
    final service = ModelService.byName(args['provider'] as String);
    final config = modelSettings.profile(service);
    if (operation == 'requestModelProviderKey') {
      final navigate = openAppPage;
      if (navigate == null) throw StateError('请先回到 Aurai 再填写密钥');
      final request = <String, Object?>{
        'page': 'providerKey',
        'service': service.name,
        'baseUrl': config.baseUrl,
        'cancelled': cancelled,
        'saved': false,
      };
      await navigate(request);
      return {
        'provider': service.name,
        'saved': request['saved'],
        'cancelled': request['saved'] != true,
      };
    }
    if (!config.isConfigured)
      throw StateError('请先使用 requestModelProviderKey 请用户填写密钥');
    if (operation == 'listProviderModels') {
      final catalog = ModelCatalog();
      try {
        final models = await catalog.load(
          baseUrl: Uri.parse(config.baseUrl),
          apiKey: config.apiKey,
          openRouter: service == ModelService.openRouter,
        );
        return {
          'provider': service.name,
          'models': models,
          'chatVerified': false,
        };
      } finally {
        catalog.close();
      }
    }
    if (operation == 'checkModelProvider')
      return checkProviderConnection(config, args['model'] as String);
    throw ArgumentError('不支持的供应商操作');
  }

  Future<void> saveProviderKey(
    ModelService service,
    String baseUrl,
    String key,
    ValueNotifier<bool> cancelled,
  ) => _serializeModelSettings(() async {
    if (cancelled.value) throw StateError('操作已取消');
    final old = modelSettings.profile(service);
    if (old.baseUrl != baseUrl) throw StateError('供应商地址已修改，请重新打开密钥填写弹框');
    if (key.trim().isEmpty) throw ArgumentError('请输入 API 密钥');
    await _saveConfig(
      ModelConfig(
        service: service,
        apiKey: key.trim(),
        baseUrl: old.baseUrl,
        model: old.model,
        reasoning: old.reasoning,
      ),
      defaultService: modelSettings.activeService,
    );
  });
}
