import 'package:flutter/material.dart';

import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import '../../domain/image_generation_config.dart';
import '../../domain/model_provider.dart';
import '../../providers/image_generation_client.dart';
import '../../providers/model_catalog.dart';
import '../../providers/openrouter_models.dart';
import 'chat_controller.dart';
import 'choice_sheet.dart';
import 'model_replacement_page.dart';
import 'model_provider_icon.dart';
import 'model_settings_sheet.dart';
import 'music_generation_settings_page.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class DefaultModelsPage extends StatefulWidget {
  const DefaultModelsPage({super.key, required this.controller});

  final ChatController controller;

  @override
  State<DefaultModelsPage> createState() => _DefaultModelsPageState();
}

class _DefaultModelsPageState extends State<DefaultModelsPage> {
  ModelPurpose? _loading;
  ModelCatalog? _catalog;
  ImageGenerationClient? _imageClient;

  @override
  void dispose() {
    _catalog?.close();
    _imageClient?.close();
    super.dispose();
  }

  void _notice(String message) => ScaffoldMessenger.of(
    context,
  ).showGlassSnackBar(SnackBar(content: Text(message)));

  Future<void> _providers() => ModelSettingsSheet.show(
    context,
    controller: widget.controller,
    continueAfterSave: false,
    accountOnly: true,
  );

  Future<void> _replaceModels(ModelPurpose purpose) async {
    final result = await Navigator.push<ModelReplacementImpact>(
      context,
      MaterialPageRoute(
        builder: (_) => ModelReplacementPage(
          controller: widget.controller,
          purpose: purpose,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {});
    final summary = [
      if (result.aiCount > 0) '${result.aiCount} 个 AI',
      for (final affected in ModelPurpose.values)
        if (result.purposes.contains(affected)) affected.label,
    ].join('、');
    _notice('已更换$summary');
  }

  Future<void> _select(ModelPurpose purpose) async {
    final service = _currentService(purpose);
    if (service == null ||
        !widget.controller.modelSettings.profile(service).isConfigured) {
      await _selectProvider(purpose);
      return;
    }
    if (purpose == ModelPurpose.imageGeneration) {
      await _selectImageModel(service);
    } else {
      await _selectGeneralModel(purpose, service);
    }
  }

  ModelService? _currentService(ModelPurpose purpose) => switch (purpose) {
    ModelPurpose.imageGeneration => widget.controller.imageGeneration?.service,
    ModelPurpose.text =>
      widget.controller.modelSettings.modelDefaults[purpose]?.service ??
          widget.controller.modelSettings.activeService,
    ModelPurpose.videoGeneration =>
      widget.controller.modelSettings.modelDefaults[purpose]?.service,
  };

  List<ModelConfig> _accounts(ModelPurpose purpose) => widget
      .controller
      .modelSettings
      .profiles
      .values
      .where(
        (profile) =>
            profile.isConfigured &&
            switch (purpose) {
              ModelPurpose.imageGeneration =>
                profile.service == ModelService.openRouter ||
                    profile.service == ModelService.qwen,
              ModelPurpose.videoGeneration => true,
              ModelPurpose.text => true,
            },
      )
      .toList();

  Future<void> _selectProvider(ModelPurpose purpose) async {
    var accounts = _accounts(purpose);
    if (accounts.isEmpty) {
      await _providers();
      if (!mounted) return;
      accounts = _accounts(purpose);
      if (accounts.isEmpty) return;
    }
    final service = await showChoiceSheet<ModelService?>(
      context,
      title: '选择供应商',
      selected: _currentService(purpose),
      choices: [
        for (final account in accounts)
          (value: account.service, label: account.displayName),
      ],
    );
    if (!mounted || service == null) return;
    if (purpose == ModelPurpose.imageGeneration) {
      await _selectImageModel(service);
    } else {
      await _selectGeneralModel(purpose, service);
    }
  }

  Future<void> _selectGeneralModel(
    ModelPurpose purpose,
    ModelService service,
  ) async {
    final account = widget.controller.modelSettings.profile(service);
    setState(() => _loading = purpose);
    try {
      final catalog = ModelCatalog();
      _catalog = catalog;
      final models = purpose == ModelPurpose.text && !account.autoSyncModels
          ? account.savedModels
          : await catalog.load(
              baseUrl: Uri.parse(account.baseUrl),
              apiKey: account.apiKey,
              openRouter: service == ModelService.openRouter,
              textOnly: purpose == ModelPurpose.text,
            );
      final choices = <DefaultModelSelection>[];
      for (final model in models) {
        final info = service == ModelService.openRouter
            ? OpenRouterModels.lookup(account.baseUrl, model)
            : null;
        final eligible = switch (purpose) {
          ModelPurpose.text => info?.supportsText ?? true,
          ModelPurpose.videoGeneration =>
            info?.outputModalities.contains('video') ?? true,
          ModelPurpose.imageGeneration => false,
        };
        if (eligible) {
          choices.add(
            DefaultModelSelection(
              service: service,
              model: model,
              name: info?.name ?? modelDisplayName(model),
            ),
          );
        }
      }
      if (!mounted) return;
      if (choices.isEmpty) {
        throw StateError(
          '该供应商当前没有可用于${purpose.label.replaceFirst('模型', '')}的模型',
        );
      }
      final currentModel =
          widget.controller.modelSettings.modelDefaults[purpose]?.model ??
          (purpose == ModelPurpose.text
              ? widget.controller.modelSettings.activeConfig.model
              : null);
      final choice = await showChoiceSheet<String?>(
        context,
        title: purpose.label,
        selected: currentModel,
        choices: [
          for (final choice in choices)
            (value: choice.model, label: choice.name),
        ],
      );
      if (!mounted || choice == null) return;
      await widget.controller.saveDefaultModel(
        purpose,
        choices.firstWhere((item) => item.model == choice),
      );
      if (mounted) setState(() {});
    } on Object catch (error) {
      if (mounted) _notice(errorMessage(error));
    } finally {
      _catalog?.close();
      _catalog = null;
      if (mounted) setState(() => _loading = null);
    }
  }

  Future<void> _selectImageModel(ModelService service) async {
    setState(() => _loading = ModelPurpose.imageGeneration);
    final client = ImageGenerationClient();
    _imageClient = client;
    try {
      final models = await client.models(
        widget.controller.modelSettings.profile(service),
      );
      if (!mounted) return;
      if (models.isEmpty) throw StateError('该供应商当前没有可用的图片生成模型');
      final selected = await showChoiceSheet<String?>(
        context,
        title: ModelPurpose.imageGeneration.label,
        selected: widget.controller.imageGeneration?.service == service
            ? widget.controller.imageGeneration?.model.id
            : null,
        choices: [
          for (final model in models) (value: model.id, label: model.name),
        ],
      );
      if (!mounted || selected == null) return;
      await widget.controller.saveImageGeneration(
        ImageGenerationConfig(
          service: service,
          model: models.firstWhere((model) => model.id == selected),
        ),
      );
      if (mounted) setState(() {});
    } on Object catch (error) {
      if (mounted) _notice(errorMessage(error));
    } finally {
      client.close();
      _imageClient = null;
      if (mounted) setState(() => _loading = null);
    }
  }

  String _subtitle(ModelPurpose purpose) {
    final settings = widget.controller.modelSettings;
    if (purpose == ModelPurpose.imageGeneration) {
      final selected = widget.controller.imageGeneration;
      return selected?.model.name ?? '未设置';
    }
    final selected = settings.modelDefaults[purpose];
    if (selected != null) {
      return settings.profile(selected.service).isConfigured
          ? selected.name
          : '未设置';
    }
    if (purpose == ModelPurpose.text) {
      final config = settings.activeConfig;
      return config.isConfigured ? modelDisplayName(config.model) : '未设置';
    }
    return '未设置';
  }

  bool _hasSelection(ModelPurpose purpose) {
    if (purpose == ModelPurpose.imageGeneration) {
      return widget.controller.imageGeneration != null;
    }
    final settings = widget.controller.modelSettings;
    final selected = settings.modelDefaults[purpose];
    if (selected != null) {
      return settings.profile(selected.service).isConfigured;
    }
    return purpose == ModelPurpose.text && settings.activeConfig.isConfigured;
  }

  String _sectionTitle(ModelPurpose purpose) => switch (purpose) {
    ModelPurpose.text => '默认文本模型',
    ModelPurpose.imageGeneration => '默认图片生成模型',
    ModelPurpose.videoGeneration => '默认视频生成模型',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: SettingsAppBar(
      gradientBackground: true,
      title: '模型设置',
      onBack: () => Navigator.pop(context),
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              View.of(context).padding.top / View.of(context).devicePixelRatio +
                  76 +
                  8,
              16,
              32,
            ),
            children: [
              for (final purpose in ModelPurpose.values) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 8, 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _sectionTitle(purpose),
                          style: TextStyle(
                            fontSize: 15,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (purpose == ModelPurpose.text)
                        TextButton(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: _loading == null
                              ? () => _replaceModels(purpose)
                              : null,
                          child: const Text('批量修改'),
                        ),
                    ],
                  ),
                ),
                Material(
                  color: settingsFieldColor(context),
                  borderRadius: BorderRadius.circular(24),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    leading: _providerButton(purpose),
                    title: Text(
                      _subtitle(purpose),
                      style: _hasSelection(purpose)
                          ? null
                          : TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                    ),
                    trailing: _loading == purpose
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const SettingsIcon(type: SettingsIconType.chevron),
                    onTap: _loading == null ? () => _select(purpose) : null,
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 8, 2),
                child: Text(
                  '音乐生成',
                  style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Material(
                color: settingsFieldColor(context),
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  leading: const SizedBox.square(
                    dimension: 44,
                    child: Center(
                      child: SettingsIcon(type: SettingsIconType.modelProvider),
                    ),
                  ),
                  title: Text(
                    widget.controller.musicGeneration?.apiKey.isNotEmpty == true
                        ? 'Suno API 平台（第三方）'
                        : '未设置',
                  ),
                  trailing: const SettingsIcon(type: SettingsIconType.chevron),
                  onTap: () async {
                    await Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MusicGenerationSettingsPage(
                          controller: widget.controller,
                        ),
                      ),
                    );
                    if (mounted) setState(() {});
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _providerButton(ModelPurpose purpose) {
    final service = _currentService(purpose);
    return Semantics(
      button: true,
      label: '切换供应商',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _loading == null ? () => _selectProvider(purpose) : null,
        child: service == null
            ? const SizedBox.square(
                dimension: 44,
                child: Center(
                  child: SettingsIcon(type: SettingsIconType.modelProvider),
                ),
              )
            : ModelProviderIcon(service: service),
      ),
    );
  }
}
