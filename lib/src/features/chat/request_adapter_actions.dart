part of 'chat_controller.dart';

extension RequestAdapterActions on ChatController {
  ModelConfig requestAdapterConfig(
    ModelService service,
    String model,
    RequestAdapter adapter,
  ) {
    final old = modelSettings.profile(service);
    final sampleModel = model.isEmpty ? old.model : model;
    return old.copyWith(
      model: sampleModel,
      details: ProviderDetails(
        name: old.displayName,
        website: old.website,
        protocol: old.protocol,
        models: old.savedModels,
        autoSyncModels: old.autoSyncModels,
        requestAdapters: {
          ...?old.details?.requestAdapters,
          sampleModel: adapter,
        },
      ),
    );
  }

  Future<void> saveRequestAdapter(
    ModelService service,
    String model,
    RequestAdapter adapter,
  ) => _serializeModelSettings(() async {
    final preview = requestAdapterConfig(service, model, adapter);
    await previewRequestAdapter(preview);
    final old = modelSettings.profile(service);
    final adapters = {...?old.details?.requestAdapters};
    if (adapter.protocol == null && adapter.script.trim().isEmpty) {
      adapters.remove(model);
    } else {
      adapters[model] = adapter;
    }
    await _saveConfig(
      old.copyWith(
        details: ProviderDetails(
          name: old.displayName,
          website: old.website,
          protocol: old.protocol,
          models: old.savedModels,
          autoSyncModels: old.autoSyncModels,
          requestAdapters: adapters,
        ),
      ),
      defaultService: modelSettings.activeService,
    );
  });

  Future<void> saveRequestAdapters(
    ModelService service,
    Map<String, RequestAdapter> drafts,
    Map<String, RequestAdapter> initial,
  ) => _serializeModelSettings(() async {
    for (final entry in drafts.entries) {
      await previewRequestAdapter(
        requestAdapterConfig(service, entry.key, entry.value),
      );
    }
    final old = modelSettings.profile(service);
    final merged = {...?old.details?.requestAdapters};
    for (final key in {...initial.keys, ...drafts.keys}) {
      if (jsonEncode(initial[key]?.toJson()) ==
          jsonEncode(drafts[key]?.toJson()))
        continue;
      if (drafts.containsKey(key)) {
        merged[key] = drafts[key]!;
      } else {
        merged.remove(key);
      }
    }
    await _saveConfig(
      old.copyWith(
        details: ProviderDetails(
          name: old.displayName,
          website: old.website,
          protocol: old.protocol,
          models: old.savedModels,
          autoSyncModels: old.autoSyncModels,
          requestAdapters: merged,
        ),
      ),
      defaultService: modelSettings.activeService,
    );
  });

  Future<Map<String, Object?>> requestAdapterTool(
    String name,
    Map<String, Object?> args,
  ) async {
    final service = ModelService.byName(args['provider'] as String);
    if (name == 'readRequestAdapters') {
      final config = modelSettings.profile(service);
      return {
        'protocol': config.protocol.name,
        'adapters': {
          for (final e
              in (config.details?.requestAdapters ?? <String, RequestAdapter>{})
                  .entries)
            e.key: e.value.toJson(),
        },
      };
    }
    final model = args['model'] as String;
    final adapter = RequestAdapter.fromJson(Map<String, dynamic>.from(args));
    if (name == 'previewRequestAdapter') {
      return previewRequestAdapter(
        requestAdapterConfig(service, model, adapter),
      );
    }
    await saveRequestAdapter(service, model, adapter);
    return {
      'saved': true,
      'validation': 'local synthetic request only; not network tested',
    };
  }
}
