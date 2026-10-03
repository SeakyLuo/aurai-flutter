import 'floating_search_layout.dart';
import 'provider_settings_draft.dart';
import '../../widgets/empty_data_view.dart';
import 'default_model_settings_page.dart';
import 'header_action_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'menu_press_highlight.dart';
import 'copy_icon.dart';
import 'conversation_menu_icon.dart';
import 'glass_surface.dart';
import 'list_sort_handle.dart';
import 'model_type_recognition_page.dart';
import '../../app/ui_action.dart';

import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import '../../domain/model_provider.dart';
import '../../providers/model_catalog.dart';
import '../../providers/model_purpose_catalog.dart';
import '../../skills/skill_icon.dart';
import 'chat_controller.dart';
import 'model_detail_page.dart';
import 'model_list_skeleton.dart';
import 'provider_models_page.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class ProviderModelManagementPage extends StatefulWidget {
  const ProviderModelManagementPage({
    super.key,
    required this.controller,
    required this.service,
    this.draft,
    required this.onConfigureTypes,
    this.readOnly = false,
  });

  final ChatController controller;
  final ModelService service;
  final ProviderSettingsDraft? draft;
  final Future<bool> Function() onConfigureTypes;
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
  bool _removing = false;
  bool _editing = false;
  List<String>? _sortModels;
  bool get _readOnly => widget.readOnly && !_editing;
  ProviderSettingsDraft? get _draft => widget.readOnly ? null : widget.draft;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _catalog?.close();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final config =
        (_draft?.config ??
        widget.controller.modelSettings.profile(widget.service));
    if (!config.isConfigured && !config.isSpeechConfigured) return;
    setState(() => _loading = true);
    final catalog = ModelCatalog();
    _catalog = catalog;
    try {
      final models = await catalog.loadFor(config);
      if (mounted) setState(() => _remoteModels = models);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showToast(
          SnackBar(content: Text(errorMessage(error))),
          kind: ToastKind.error,
        );
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
          draft: _draft,
          model: model,
          readOnly: _readOnly,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _chooseModels() async {
    final config =
        (_draft?.config ??
        widget.controller.modelSettings.profile(widget.service));
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
    await _saveModels(selection);
  }

  Future<void> _removeModel(String model) => _saveModels((
    useAll: false,
    models: [
      ...{
        ...(_draft?.config ??
                widget.controller.modelSettings.profile(widget.service))
            .savedModels,
        if ((_draft?.config ??
                widget.controller.modelSettings.profile(widget.service))
            .autoSyncModels)
          ..._remoteModels,
      }.where((item) => item != model),
    ],
  ));

  Future<void> _modelMenu(
    BuildContext anchor,
    String model,
    Offset position,
  ) async {
    final action = await showHeaderActionMenu(
      anchor,
      position: position,
      items: [
        if (_readOnly) ...[
          (
            value: 'open',
            label: '查看详情',
            icon: const SettingsIcon(type: SettingsIconType.model),
          ),
          (value: 'copy', label: '复制名称', icon: const CopyIcon()),
        ] else
          (
            value: 'remove',
            label: '删除模型',
            icon: const ConversationMenuIcon(
              type: ConversationMenuIconType.delete,
            ),
          ),
      ],
      destructiveValues: const {'remove'},
    );
    if (!mounted) return;
    if (action == 'open') await _open(model);
    if (action == 'copy') {
      await Clipboard.setData(
        ClipboardData(
          text:
              (_draft?.config ??
                      widget.controller.modelSettings.profile(widget.service))
                  .displayModel(model),
        ),
      );
      if (mounted)
        ScaffoldMessenger.of(context).showToast(
          const SnackBar(content: Text('已复制名称')),
          kind: ToastKind.success,
        );
    }
    if (mounted && action == 'remove' && !_savingSelection) {
      await _removeModel(model);
    }
  }

  Future<void> _saveModels(
    ({bool useAll, List<String> models}) selection,
  ) async {
    setState(() => _savingSelection = true);
    try {
      final current =
          (_draft?.config ??
          widget.controller.modelSettings.profile(widget.service));
      final details = current.details;
      await saveProviderEditorConfig(
        widget.controller,
        _draft,
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
            modelPurposeField: details?.modelPurposeField ?? '',
            modelTypeMappings: details?.modelTypeMappings ?? const {},
            modelReasoning: details?.modelReasoning ?? const {},
            speechApi: details?.speechApi,
            speechApiKey: details?.speechApiKey ?? '',
            modelCatalog: details?.modelCatalog ?? const [],
            modelApiNames: details?.modelApiNames ?? const {},
            balance: details?.balance,
            icon: details?.icon,
          ),
        ),
        defaultService: widget.controller.modelSettings.activeService,
      );
      if (!mounted) return;
      setState(() => _search.clear());
      if (mounted) setState(() => _sortModels = null);
      if (selection.useAll && _remoteModels.isEmpty) await _load();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showToast(
          SnackBar(content: Text(errorMessage(error))),
          kind: ToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _savingSelection = false);
    }
  }

  Future<void> _more(BuildContext anchor) async {
    final config =
        (_draft?.config ??
        widget.controller.modelSettings.profile(widget.service));
    final action = await showHeaderActionMenu(
      anchor,
      items: [
        (
          value: 'sort',
          label: '调整顺序',
          icon: const SettingsIcon(type: SettingsIconType.sort),
        ),
        if (!_readOnly)
          (
            value: 'remove',
            label: '移除模型',
            icon: const ConversationMenuIcon(
              type: ConversationMenuIconType.delete,
            ),
          ),
        (
          value: 'defaults',
          label: '默认模型设置',
          icon: const SettingsIcon(type: SettingsIconType.model),
        ),
        if (config.protocol.supportsChatModels)
          (
            value: 'types',
            label: '模型类型识别',
            icon: const SettingsIcon(type: SettingsIconType.field),
          ),
      ],
    );
    if (!mounted) return;
    if (action == 'sort') {
      FocusScope.of(context).unfocus();
      setState(() {
        _search.clear();
        _sortModels = {
          ...config.savedModels,
          if (config.autoSyncModels) ..._remoteModels,
        }.toList();
      });
    }
    if (action == 'remove') setState(() => _removing = true);
    if (action == 'defaults') {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => DefaultModelSettingsPage(
            controller: widget.controller,
            service: widget.service,
            draft: _draft,
            readOnly: _readOnly,
          ),
        ),
      );
      if (mounted) setState(() {});
    }
    if (action == 'types') await _configureTypes();
  }

  Future<void> _configureTypes() async {
    if (!widget.readOnly) {
      await widget.onConfigureTypes();
      if (mounted) setState(() {});
      return;
    }
    final result = await Navigator.push<ModelTypeSettings>(
      context,
      MaterialPageRoute(
        builder: (_) => ModelTypeRecognitionPage(
          config: widget.controller.modelSettings.profile(widget.service),
          readOnly: _readOnly,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _savingSelection = true);
    await runUiAction(context, () async {
      final current = widget.controller.modelSettings.profile(widget.service);
      final draft = ProviderSettingsDraft(current);
      draft.updateDetails({
        'modelPurposeField': result.path,
        'modelTypeMappings': {
          for (final entry in result.mappings.entries)
            entry.key: entry.value.name,
        },
      });
      await widget.controller.saveConfig(
        draft.config,
        defaultService: widget.controller.modelSettings.activeService,
      );
    });
    if (mounted) setState(() => _savingSelection = false);
  }

  String _modelIcon(ModelConfig config, String model) {
    final purposes = modelPurposesFor(config, model);
    if (purposes.contains(ModelPurpose.speechSynthesis)) return 'speech';
    if (purposes.contains(ModelPurpose.musicGeneration)) return 'music';
    if (purposes.contains(ModelPurpose.videoGeneration)) return 'video';
    if (purposes.contains(ModelPurpose.imageGeneration)) return 'photo';
    if (purposes.contains(ModelPurpose.text)) return 'text';
    return 'model';
  }

  @override
  Widget build(BuildContext context) {
    final config =
        (_draft?.config ??
        widget.controller.modelSettings.profile(widget.service));
    final canChoose = config.isConfigured || config.isSpeechConfigured;
    final selectedModels = config.autoSyncModels
        ? {...config.savedModels, ..._remoteModels}
        : config.savedModels.toSet();
    final query = selectedModels.length >= 20
        ? _search.text.trim().toLowerCase()
        : '';
    final models =
        _sortModels ??
        selectedModels
            .where(
              (model) =>
                  config.apiModelFor(model).toLowerCase().contains(query) ||
                  config.displayModel(model).toLowerCase().contains(query),
            )
            .toList();
    return PopScope(
      canPop: _sortModels == null && !_savingSelection,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_savingSelection && _sortModels != null) {
          setState(() => _sortModels = null);
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: SettingsAppBar(
          title: _sortModels != null
              ? '模型排序'
              : widget.readOnly && _editing && !_removing
              ? ''
              : '模型管理',
          onBack: _savingSelection
              ? null
              : () {
                  if (_sortModels != null) {
                    setState(() => _sortModels = null);
                  } else if (_removing) {
                    setState(() => _removing = false);
                  } else {
                    Navigator.pop(context);
                  }
                },
          actions: [
            if (_sortModels != null)
              SettingsGlassAction(
                label: '完成排序',
                icon: Icons.check_rounded,
                iconWidget: const SettingsIcon(type: SettingsIconType.check),
                onPressed: _savingSelection
                    ? null
                    : () async {
                        await _saveModels((
                          useAll: config.autoSyncModels,
                          models: _sortModels!,
                        ));
                      },
              )
            else if (_removing)
              SettingsGlassAction(
                label: '完成',
                icon: Icons.check_rounded,
                iconWidget: const SettingsIcon(type: SettingsIconType.check),
                onPressed: _savingSelection
                    ? null
                    : () => setState(() => _removing = false),
              )
            else
              SettingsGlassActionSurface(
                child: SizedBox(
                  height: 40,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.readOnly) ...[
                        RoundAction(
                          label: _editing ? '完成' : '编辑',
                          icon: _editing
                              ? Icons.check_rounded
                              : Icons.edit_outlined,
                          iconWidget: _editing
                              ? const SettingsIcon(type: SettingsIconType.check)
                              : const ConversationMenuIcon(
                                  type: ConversationMenuIconType.rename,
                                ),
                          onPressed: _savingSelection
                              ? null
                              : () => setState(() => _editing = !_editing),
                        ),
                        VerticalDivider(
                          width: 1,
                          thickness: 1,
                          indent: 10,
                          endIndent: 10,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: .12),
                        ),
                      ],
                      if (!_readOnly) ...[
                        RoundAction(
                          label: '添加模型',
                          icon: Icons.add_rounded,
                          iconWidget: const SettingsIcon(
                            type: SettingsIconType.add,
                          ),
                          onPressed: _savingSelection || _loading || !canChoose
                              ? null
                              : _chooseModels,
                        ),
                        VerticalDivider(
                          width: 1,
                          thickness: 1,
                          indent: 10,
                          endIndent: 10,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: .12),
                        ),
                      ],
                      Builder(
                        builder: (anchor) => RoundAction(
                          label: '更多',
                          icon: Icons.more_vert,
                          iconWidget: const SettingsIcon(
                            type: SettingsIconType.more,
                          ),
                          onPressed: _savingSelection || _loading
                              ? null
                              : () => _more(anchor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        body: SettingsPageBody(
          child: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  children: [
                    Expanded(
                      child: FloatingSearchLayout(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        hintText: '搜索已选模型',
                        enabled:
                            _sortModels == null && selectedModels.length >= 20,
                        bottom: 16,
                        child: _loading && selectedModels.isEmpty
                            ? ModelListSkeleton(
                                padding: settingsPagePadding(
                                  context,
                                  const EdgeInsets.fromLTRB(20, 12, 20, 16),
                                ),
                              )
                            : models.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: EmptyDataView(
                                    title: query.isNotEmpty
                                        ? '没有匹配的模型'
                                        : canChoose
                                        ? '还没有添加的模型'
                                        : '请先返回供应商页填写 API 密钥',
                                    actionText: query.isNotEmpty
                                        ? '清除搜索'
                                        : null,
                                    onAction: () =>
                                        setState(() => _search.clear()),
                                  ),
                                ),
                              )
                            : ReorderableListView.builder(
                                buildDefaultDragHandles: false,
                                proxyDecorator: (child, index, animation) =>
                                    child,
                                onReorderItem: (oldIndex, newIndex) =>
                                    setState(() {
                                      _sortModels!.insert(
                                        newIndex,
                                        _sortModels!.removeAt(oldIndex),
                                      );
                                    }),
                                padding: settingsPagePadding(
                                  context,
                                  EdgeInsets.fromLTRB(
                                    4,
                                    4,
                                    4,
                                    _sortModels == null &&
                                            selectedModels.length >= 20
                                        ? FloatingSearchLayout.clearance
                                        : 16,
                                  ),
                                ),
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                itemCount: models.length,
                                itemBuilder: (context, index) {
                                  final model = models[index];
                                  return Theme(
                                    key: ValueKey(model),
                                    data: Theme.of(context).copyWith(
                                      splashFactory: NoSplash.splashFactory,
                                      highlightColor: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: .06),
                                    ),
                                    child: Builder(
                                      builder: (anchor) => MenuPressHighlight(
                                        borderRadius: BorderRadius.circular(24),
                                        onLongPressStart:
                                            _savingSelection ||
                                                _loading ||
                                                _removing ||
                                                _sortModels != null
                                            ? null
                                            : (details) => _modelMenu(
                                                anchor,
                                                model,
                                                details.globalPosition,
                                              ),
                                        child: Theme(
                                          data: Theme.of(context).copyWith(
                                            splashFactory:
                                                NoSplash.splashFactory,
                                            highlightColor: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: .06),
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                            clipBehavior: Clip.antiAlias,
                                            child: ListTile(
                                              minTileHeight: 60,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                  ),
                                              title: Row(
                                                children: [
                                                  Container(
                                                    width: 36,
                                                    height: 36,
                                                    alignment: Alignment.center,
                                                    decoration: BoxDecoration(
                                                      color: settingsFieldColor(
                                                        context,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                    child: ColorFiltered(
                                                      colorFilter:
                                                          ColorFilter.mode(
                                                            Theme.of(context)
                                                                .colorScheme
                                                                .onSurfaceVariant,
                                                            BlendMode.srcIn,
                                                          ),
                                                      child: SkillIcon(
                                                        _modelIcon(
                                                          config,
                                                          model,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      config.displayModel(
                                                        model,
                                                      ),
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              trailing: _sortModels != null
                                                  ? ListSortHandle(
                                                      index: index,
                                                      enabled:
                                                          !_savingSelection,
                                                    )
                                                  : _removing
                                                  ? IconButton(
                                                      tooltip: '移除模型',
                                                      onPressed:
                                                          _savingSelection ||
                                                              _loading
                                                          ? null
                                                          : () => _removeModel(
                                                              model,
                                                            ),
                                                      icon: ConversationMenuIcon(
                                                        type:
                                                            ConversationMenuIconType
                                                                .delete,
                                                        color: Theme.of(
                                                          context,
                                                        ).colorScheme.error,
                                                      ),
                                                    )
                                                  : const SettingsIcon(
                                                      type: SettingsIconType
                                                          .chevron,
                                                    ),
                                              onTap:
                                                  _savingSelection ||
                                                      _removing ||
                                                      _sortModels != null
                                                  ? null
                                                  : () => _open(model),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
