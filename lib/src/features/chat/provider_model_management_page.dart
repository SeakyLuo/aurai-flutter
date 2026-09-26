import 'package:flutter/material.dart';

import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import '../../domain/model_provider.dart';
import '../../providers/model_catalog.dart';
import '../../providers/model_purpose_catalog.dart';
import '../../skills/skill_icon.dart';
import 'chat_controller.dart';
import 'model_detail_page.dart';
import 'model_search_field.dart';
import 'provider_models_page.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class ProviderModelManagementPage extends StatefulWidget {
  const ProviderModelManagementPage({
    super.key,
    required this.controller,
    required this.service,
    this.readOnly = false,
  });

  final ChatController controller;
  final ModelService service;
  final bool readOnly;

  @override
  State<ProviderModelManagementPage> createState() =>
      _ProviderModelManagementPageState();
}

class _ProviderModelManagementPageState
    extends State<ProviderModelManagementPage> {
  final _search = TextEditingController();
  ModelCatalog? _catalog;
  List<String> _remoteModels = const [];
  bool _loading = false;
  bool _savingSelection = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller.modelSettings
        .profile(widget.service)
        .autoSyncModels) {
      _load();
    }
  }

  @override
  void dispose() {
    _catalog?.close();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final config = widget.controller.modelSettings.profile(widget.service);
    if (!config.isConfigured) return;
    setState(() => _loading = true);
    final catalog = ModelCatalog();
    _catalog = catalog;
    try {
      final models = await catalog.loadFor(config);
      if (mounted) setState(() => _remoteModels = models);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showGlassSnackBar(SnackBar(content: Text(errorMessage(error))));
      }
    } finally {
      catalog.close();
      _catalog = null;
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(String model) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ModelDetailPage(
          controller: widget.controller,
          service: widget.service,
          model: model,
          readOnly: widget.readOnly,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _chooseModels() async {
    final config = widget.controller.modelSettings.profile(widget.service);
    final selection =
        await showModalBottomSheet<({bool useAll, List<String> models})>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: false,
          builder: (_) => ProviderModelsPage(
            controller: widget.controller,
            config: config,
            selectable: true,
          ),
        );
    if (!mounted || selection == null) return;
    setState(() => _savingSelection = true);
    try {
      final current = widget.controller.modelSettings.profile(widget.service);
      final details = current.details;
      await widget.controller.saveConfig(
        current.copyWith(
          model:
              !selection.useAll &&
                  !selection.models.contains(current.model) &&
                  selection.models.isNotEmpty
              ? selection.models.first
              : current.model,
          details: ProviderDetails(
            name: current.displayName,
            website: current.website,
            protocol: current.protocol,
            models: selection.models,
            autoSyncModels: selection.useAll,
            requestAdapters: details?.requestAdapters ?? const {},
            modelContextOverrides: details?.modelContextOverrides ?? const {},
            modelPurposes: details?.modelPurposes ?? const {},
            modelReasoning: details?.modelReasoning ?? const {},
            balance: details?.balance,
            icon: details?.icon,
          ),
        ),
        defaultService: widget.controller.modelSettings.activeService,
      );
      if (!mounted) return;
      setState(() => _search.clear());
      if (selection.useAll && _remoteModels.isEmpty) await _load();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showGlassSnackBar(SnackBar(content: Text(errorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _savingSelection = false);
    }
  }

  String _modelIcon(ModelConfig config, String model) {
    final purposes = modelPurposesFor(config, model);
    if (purposes.contains(ModelPurpose.musicGeneration)) return 'music';
    if (purposes.contains(ModelPurpose.videoGeneration)) return 'video';
    if (purposes.contains(ModelPurpose.imageGeneration)) return 'photo';
    if (purposes.contains(ModelPurpose.text)) return 'text';
    return 'model';
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.controller.modelSettings.profile(widget.service);
    final canChoose = config.isConfigured;
    final query = _search.text.trim().toLowerCase();
    final selectedModels = config.autoSyncModels
        ? {..._remoteModels, ...config.savedModels}
        : config.savedModels.toSet();
    final models =
        selectedModels
            .where((model) => model.toLowerCase().contains(query))
            .toList()
          ..sort();
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        title: '模型管理',
        onBack: _savingSelection ? null : () => Navigator.pop(context),
        actions: widget.readOnly
            ? const []
            : [
                SettingsGlassAction(
                  label: '添加模型',
                  icon: Icons.add_rounded,
                  iconWidget: const SettingsIcon(type: SettingsIconType.add),
                  onPressed: !canChoose || _savingSelection || _loading
                      ? null
                      : _chooseModels,
                ),
              ],
      ),
      body: SettingsPageBody(
        avoidHeader: true,
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                children: [
                  if (selectedModels.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: ModelSearchField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        hintText: '搜索已选模型',
                      ),
                    ),
                  Expanded(
                    child: _loading && selectedModels.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : models.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    query.isNotEmpty
                                        ? '没有匹配的模型'
                                        : canChoose
                                        ? '还没有添加的模型'
                                        : '请先返回供应商页填写 API 密钥',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  if (query.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    TextButton(
                                      onPressed: () =>
                                          setState(() => _search.clear()),
                                      child: const Text('清除搜索'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            itemCount: models.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final model = models[index];
                              return Material(
                                color: settingsFieldColor(context),
                                borderRadius: BorderRadius.circular(22),
                                clipBehavior: Clip.antiAlias,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 10,
                                  ),
                                  title: Row(
                                    children: [
                                      ColorFiltered(
                                        colorFilter: ColorFilter.mode(
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                          BlendMode.srcIn,
                                        ),
                                        child: SkillIcon(
                                          _modelIcon(config, model),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          modelDisplayName(
                                            config.protocol.displayModel(model),
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: const SettingsIcon(
                                    type: SettingsIconType.chevron,
                                  ),
                                  onTap: () => _open(model),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
