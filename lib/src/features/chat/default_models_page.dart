import '../../app/glass_notice.dart';
import 'image_generation_settings_page.dart';
import 'package:flutter/material.dart';
import '../../domain/error_message.dart';
import '../../domain/model_provider.dart';
import '../../providers/model_catalog.dart';
import '../../providers/openrouter_models.dart';
import 'chat_controller.dart';
import 'choice_sheet.dart';
import 'model_settings_sheet.dart';
import 'model_replacement_page.dart';
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

  @override
  void dispose() {
    _catalog?.close();
    super.dispose();
  }

  Future<void> _providers() async {
    await ModelSettingsSheet.show(
      context,
      controller: widget.controller,
      continueAfterSave: false,
      accountOnly: true,
    );
    if (mounted) setState(() {});
  }

  Future<void> _replaceModels() async {
    final result = await Navigator.push<ModelReplacementImpact>(
      context,
      MaterialPageRoute(
        builder: (_) => ModelReplacementPage(controller: widget.controller),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {});
    ScaffoldMessenger.of(context).showGlassSnackBar(
      SnackBar(content: Text('已更换${_replacementSummary(result)}')),
    );
  }

  String _replacementSummary(ModelReplacementImpact impact) => [
    if (impact.aiCount > 0) '${impact.aiCount} 个 AI',
    for (final purpose in ModelPurpose.values)
      if (impact.purposes.contains(purpose)) purpose.label,
  ].join('、');

  Future<void> _select(ModelPurpose purpose) async {
    if (purpose == ModelPurpose.imageGeneration) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ImageGenerationSettingsPage(controller: widget.controller),
        ),
      );
      if (mounted) setState(() {});
      return;
    }
    final settings = widget.controller.modelSettings;
    final accounts = settings.profiles.values
        .where((profile) => profile.isConfigured)
        .toList();
    if (accounts.isEmpty) {
      await _providers();
      return;
    }
    final service = await showChoiceSheet<ModelService?>(
      context,
      title: '选择供应商',
      selected: settings.modelDefaults[purpose]?.service,
      choices: [
        for (final account in accounts)
          (value: account.service, label: account.displayName),
      ],
    );
    if (!mounted || service == null) return;
    final account = widget.controller.modelSettings.profile(service);
    setState(() => _loading = purpose);
    try {
      final choices = <DefaultModelSelection>[];
      {
        if (purpose != ModelPurpose.text &&
            service != ModelService.openRouter) {
          throw StateError('该用途暂通过 OpenRouter 读取模型能力，请选择 OpenRouter');
        }
        final catalog = ModelCatalog();
        _catalog = catalog;
        final models = purpose == ModelPurpose.text && !account.autoSyncModels
            ? account.savedModels
            : await catalog.load(
                baseUrl: Uri.parse(account.baseUrl),
                apiKey: account.apiKey,
                openRouter: service == ModelService.openRouter,
                textOnly: purpose != ModelPurpose.videoGeneration,
              );
        for (final model in models) {
          final info = service == ModelService.openRouter
              ? OpenRouterModels.lookup(account.baseUrl, model)
              : null;
          final eligible = switch (purpose) {
            ModelPurpose.text => info?.supportsText ?? true,
            ModelPurpose.imageUnderstanding =>
              info!.supportsImages && info.supportsText,
            ModelPurpose.videoUnderstanding =>
              info!.inputModalities.contains('video') && info.supportsText,
            ModelPurpose.videoGeneration => info!.outputModalities.contains(
              'video',
            ),
            ModelPurpose.imageGeneration => false,
          };
          if (eligible)
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
      if (choices.isEmpty)
        throw StateError(
          '该供应商当前没有可用于${purpose.label.replaceFirst('模型', '')}的模型',
        );
      final choice = await showChoiceSheet<String?>(
        context,
        title: purpose.label,
        selected: widget.controller.modelSettings.modelDefaults[purpose]?.model,
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
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showGlassSnackBar(SnackBar(content: Text(errorMessage(error))));
    } finally {
      _catalog?.close();
      _catalog = null;
      if (mounted) setState(() => _loading = null);
    }
  }

  String _subtitle(ModelPurpose purpose) {
    final settings = widget.controller.modelSettings;
    if (purpose == ModelPurpose.imageGeneration) {
      final selected = widget.controller.imageGeneration;
      return selected == null
          ? '未设置'
          : '${settings.profile(selected.service).displayName} · ${selected.model.name}';
    }
    final selected = settings.modelDefaults[purpose];
    if (selected != null) {
      return settings.profile(selected.service).isConfigured
          ? '${settings.profile(selected.service).displayName} · ${selected.name}'
          : '未配置供应商 · ${settings.profile(selected.service).displayName}';
    }
    if (purpose == ModelPurpose.text) {
      final config = settings.activeConfig;
      return config.isConfigured
          ? '${config.displayName} · ${modelDisplayName(config.model)}'
          : '未设置';
    }
    return '未设置';
  }

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
                  16,
              16,
              16,
            ),
            children: [
              Material(
                color: settingsFieldColor(context),
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  leading: const SettingsIcon(type: SettingsIconType.model),
                  title: const Text('更换模型'),
                  subtitle: const Text('批量替换 AI 和默认用途使用的模型'),
                  trailing: const SettingsIcon(type: SettingsIconType.chevron),
                  onTap: _loading == null ? _replaceModels : null,
                ),
              ),
              const SizedBox(height: 20),
              for (final purpose in ModelPurpose.values) ...[
                Material(
                  color: settingsFieldColor(context),
                  borderRadius: BorderRadius.circular(24),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    title: Text(purpose.label),
                    subtitle: Text(_subtitle(purpose)),
                    trailing: _loading == purpose
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const SettingsIcon(type: SettingsIconType.chevron),
                    onTap: _loading == null ? () => _select(purpose) : null,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
