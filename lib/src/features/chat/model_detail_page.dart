import 'provider_settings_draft.dart';
import 'package:flutter/material.dart';

import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import '../../domain/model_provider.dart';
import '../../providers/model_context_limits.dart';
import '../../providers/model_purpose_catalog.dart';
import 'chat_controller.dart';
import 'model_context_page.dart';
import 'model_reasoning_field.dart';
import 'request_adapter_page.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'question_icon.dart';
import '../../scheduling/task_unsaved_dialog.dart';

class ModelDetailPage extends StatefulWidget {
  const ModelDetailPage({
    super.key,
    required this.controller,
    required this.service,
    this.draft,
    required this.model,
    this.readOnly = false,
  });

  final ChatController controller;
  final ModelService service;
  final ProviderSettingsDraft? draft;
  final String model;
  final bool readOnly;

  @override
  State<ModelDetailPage> createState() => _ModelDetailPageState();
}

class _ModelDetailPageState extends State<ModelDetailPage> {
  late Set<ModelPurpose> _initialPurposes = {
    ...modelPurposesFor(_config, widget.model),
  };
  late Set<ModelPurpose> _purposes = {..._initialPurposes};
  late ModelReasoning _initialReasoning =
      _config.details?.modelReasoning[widget.model] ?? ModelReasoning.inherit;
  late ModelReasoning _reasoning = _initialReasoning;
  bool _saving = false;
  bool _allowPop = false;
  late final TextEditingController _apiName, _displayName;
  late final String _initialApiName, _initialDisplayName;

  @override
  void initState() {
    super.initState();
    _initialApiName = _config.apiModelFor(widget.model);
    _initialDisplayName = _config.displayModel(widget.model);
    _apiName = TextEditingController(text: _initialApiName);
    _displayName = TextEditingController(text: _initialDisplayName);
  }

  @override
  void dispose() {
    _apiName.dispose();
    _displayName.dispose();
    super.dispose();
  }

  bool get _dirty =>
      !_purposes.containsAll(_initialPurposes) ||
      !_initialPurposes.containsAll(_purposes) ||
      _reasoning != _initialReasoning ||
      _apiName.text.trim() != _initialApiName ||
      _displayName.text.trim() != _initialDisplayName;

  ModelConfig get _config =>
      (widget.draft?.config ??
      widget.controller.modelSettings.profile(widget.service));

  void _notice(String message, {ToastKind kind = ToastKind.info}) =>
      ScaffoldMessenger.of(
        context,
      ).showToast(SnackBar(content: Text(message)), kind: kind);

  Future<void> _save() async {
    if (_apiName.text.trim().isEmpty || _displayName.text.trim().isEmpty) {
      _notice('请填写接口名称和展示名称');
      return;
    }
    if (_purposes.isEmpty) {
      _notice('请至少选择一种模型用途', kind: ToastKind.warning);
      return;
    }
    if (_initialPurposes.contains(ModelPurpose.text) &&
        !_purposes.contains(ModelPurpose.text)) {
      final used = await widget.controller.usedModels(ModelPurpose.text);
      if (!mounted) return;
      final aiCount = used
          .where(
            (item) =>
                item.model.service == widget.service &&
                item.model.model == widget.model,
          )
          .fold<int>(0, (count, item) => count + item.impact.aiCount);
      final defaultText = widget.controller.modelSettings.activeConfig;
      final isDefault =
          defaultText.service == widget.service &&
          defaultText.model == widget.model;
      if (aiCount > 0 || isDefault) {
        _notice('此模型仍被文本功能使用。请先到模型设置或联系人的模型设置中更换模型。', kind: ToastKind.warning);
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final current = _config;
      final details = current.details;
      await saveProviderEditorConfig(
        widget.controller,
        widget.draft,
        current.copyWith(
          details: ProviderDetails(
            name: current.displayName,
            website: current.website,
            protocol: current.protocol,
            models: current.savedModels,
            autoSyncModels: current.autoSyncModels,
            requestAdapters: details?.requestAdapters ?? const {},
            speechApi: details?.speechApi,
            speechApiKey: details?.speechApiKey ?? '',
            modelCatalog: [
              for (final model
                  in details?.modelCatalog ??
                      const <({String id, String name})>[])
                if (model.id != widget.model) model,
              (id: widget.model, name: _displayName.text.trim()),
            ],
            modelApiNames:
                {
                  ...?details?.modelApiNames,
                  if (_apiName.text.trim() != widget.model)
                    widget.model: _apiName.text.trim(),
                }..removeWhere(
                  (model, _) =>
                      model == widget.model &&
                      _apiName.text.trim() == widget.model,
                ),
            balance: details?.balance,
            icon: details?.icon,
            modelContextOverrides: details?.modelContextOverrides ?? const {},
            modelPurposes: {
              ...?details?.modelPurposes,
              widget.model: _purposes,
            },
            modelPurposeField: details?.modelPurposeField ?? '',
            modelTypeMappings: details?.modelTypeMappings ?? const {},
            modelReasoning:
                {
                  ...?details?.modelReasoning,
                  if (_reasoning != ModelReasoning.inherit)
                    widget.model: _reasoning,
                }..removeWhere(
                  (model, _) =>
                      model == widget.model &&
                      _reasoning == ModelReasoning.inherit,
                ),
          ),
        ),
        defaultService: widget.controller.modelSettings.activeService,
      );
      if (mounted) {
        setState(() {
          _initialPurposes = {..._purposes};
          _initialReasoning = _reasoning;
          _allowPop = true;
        });
        Navigator.pop(context);
      }
    } on Object catch (error) {
      if (mounted)
        _notice('保存失败：${errorMessage(error)}', kind: ToastKind.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _leave() async {
    if (!_dirty) {
      setState(() => _allowPop = true);
      Navigator.pop(context);
      return;
    }
    final action = await showDialog<String>(
      context: context,
      builder: (_) => const TaskUnsavedDialog(description: '模型设置还有未保存的修改。'),
    );
    if (!mounted) return;
    if (action == 'save') {
      await _save();
    } else if (action == 'discard') {
      setState(() => _allowPop = true);
      Navigator.pop(context);
    }
  }

  Future<void> _openAdapter() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RequestAdapterPage(
          controller: widget.controller,
          service: widget.service,
          draft: widget.draft,
          initialModel: widget.model,
          readOnly: widget.readOnly,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openContext() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ModelContextPage(
          controller: widget.controller,
          service: widget.service,
          draft: widget.draft,
          initialModel: widget.model,
          fixedModel: true,
          readOnly: widget.readOnly,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _pickPurposes() async {
    final selected = {..._purposes};
    final result = await showModalBottomSheet<Set<ModelPurpose>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, updateSheet) {
          void toggle(ModelPurpose purpose) => updateSheet(() {
            if (!selected.remove(purpose)) selected.add(purpose);
          });
          final colors = Theme.of(context).colorScheme;
          final canFinish = selected.isNotEmpty;
          return SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      SettingsGlassAction(
                        label: '关闭',
                        icon: Icons.close_rounded,
                        iconWidget: const QuestionIcon(
                          type: QuestionIconType.close,
                        ),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                      const Expanded(
                        child: Text(
                          '模型用途',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SettingsGlassAction(
                        label: '完成',
                        icon: Icons.check_rounded,
                        iconWidget: SettingsIcon(
                          type: SettingsIconType.check,
                          color: colors.onSurface.withValues(
                            alpha: canFinish ? 1 : .3,
                          ),
                        ),
                        onPressed: canFinish
                            ? () => Navigator.pop(sheetContext, selected)
                            : null,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      for (final purpose in _config.supportedModelPurposes)
                        Semantics(
                          checked: selected.contains(purpose),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(20),
                              ),
                            ),
                            leading: Container(
                              width: 22,
                              height: 22,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected.contains(purpose)
                                    ? colors.onSurface
                                    : Colors.transparent,
                                border: Border.all(
                                  color: selected.contains(purpose)
                                      ? colors.onSurface
                                      : colors.outline,
                                  width: 1.4,
                                ),
                              ),
                              child: selected.contains(purpose)
                                  ? SettingsIcon(
                                      type: SettingsIconType.check,
                                      color: colors.surface,
                                    )
                                  : null,
                            ),
                            title: Text(
                              _purposeLabel(purpose),
                              style: const TextStyle(fontSize: 15),
                            ),
                            onTap: () => toggle(purpose),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (mounted && result != null) setState(() => _purposes = result);
  }

  String _purposeLabel(ModelPurpose purpose) => switch (purpose) {
    ModelPurpose.text => '文本',
    ModelPurpose.imageGeneration => '图片',
    ModelPurpose.videoGeneration => '视频',
    ModelPurpose.musicGeneration => '音乐',
    ModelPurpose.speechSynthesis => '语音合成',
  };

  @override
  Widget build(BuildContext context) {
    final adapter = _config.details?.requestAdapters[widget.model];
    final inherited = _config.details?.requestAdapters[''];
    final contextOverride =
        _config.details?.modelContextOverrides[widget.model];
    final defaultPercent =
        _config.details?.modelContextOverrides['']?.compactPercent ?? 80;
    final limits = ModelContextLimits.previewForConfig(
      _config.copyWith(model: widget.model),
    );
    if (widget.readOnly) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: SettingsAppBar(
          title: _config.displayModel(widget.model),
          onBack: () => Navigator.pop(context),
        ),
        body: SettingsPageBody(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: settingsPagePadding(
                  context,
                  const EdgeInsets.fromLTRB(12, 12, 12, 32),
                ),
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: const Text('接口名称'),
                    subtitle: Text(_initialApiName),
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: const Text('展示名称'),
                    subtitle: Text(_initialDisplayName),
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: const Text('模型用途'),
                    subtitle: Text(
                      _purposes.isEmpty
                          ? '未设置用途'
                          : ModelPurpose.values
                                .where(_purposes.contains)
                                .map(_purposeLabel)
                                .join(' · '),
                    ),
                  ),
                  if (_purposes.contains(ModelPurpose.text)) ...[
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      title: const Text('思考强度'),
                      subtitle: Text(
                        _reasoning == ModelReasoning.inherit
                            ? '继承默认设置 · ${_config.reasoning.label}'
                            : _reasoning.label,
                      ),
                    ),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                      title: const Text('请求转换'),
                      subtitle: Text(
                        adapter != null
                            ? '此模型单独配置'
                            : inherited != null
                            ? '继承供应商默认配置'
                            : '未设置',
                      ),
                      trailing: const SettingsIcon(
                        type: SettingsIconType.chevron,
                      ),
                      onTap: _openAdapter,
                    ),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                      title: const Text('上下文压缩'),
                      subtitle: Text(
                        contextOverride == null
                            ? '继承默认 ${defaultPercent}%'
                            : '此模型单独设置 · ${limits.compactPercent}%',
                      ),
                      trailing: const SettingsIcon(
                        type: SettingsIconType.chevron,
                      ),
                      onTap: _openContext,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) _leave();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: SettingsAppBar(
          title: _config.displayModel(widget.model),
          onBack: _saving ? null : _leave,
          actions: [
            SettingsGlassAction(
              label: widget.draft == null ? '保存' : '完成',
              icon: Icons.check_rounded,
              iconWidget: const SettingsIcon(type: SettingsIconType.check),
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
        body: SettingsPageBody(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: settingsPagePadding(
                  context,
                  const EdgeInsets.fromLTRB(16, 20, 16, 32),
                ),
                children: [
                  _label('接口名称'),
                  _nameField(_apiName, '接口实际使用的模型名称', 200),
                  const SizedBox(height: 24),
                  _label('展示名称'),
                  _nameField(_displayName, '在 App 中显示的名称', 60),
                  const SizedBox(height: 24),
                  _label('模型用途'),
                  Material(
                    color: settingsFieldColor(context),
                    borderRadius: BorderRadius.circular(24),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      minTileHeight: settingsCardHeight,
                      contentPadding: settingsCardPadding,
                      title: Text(
                        _purposes.isEmpty
                            ? '选择模型用途'
                            : ModelPurpose.values
                                  .where(_purposes.contains)
                                  .map(_purposeLabel)
                                  .join(' · '),
                      ),
                      trailing: const SettingsIcon(
                        type: SettingsIconType.chevronDown,
                      ),
                      onTap: _saving ? null : _pickPurposes,
                    ),
                  ),
                  if (_purposes.contains(ModelPurpose.text)) ...[
                    ModelReasoningField(
                      service: widget.service,
                      model: widget.model,
                      baseUrl: _config.baseUrl,
                      value: _reasoning,
                      inheritedValue: _config.reasoning,
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _reasoning = value),
                    ),
                    const SizedBox(height: 16),
                    _label('请求转换'),
                    Material(
                      color: settingsFieldColor(context),
                      borderRadius: BorderRadius.circular(24),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        minTileHeight: settingsCardHeight,
                        contentPadding: settingsCardPadding,
                        title: Text(
                          adapter != null
                              ? '此模型单独配置'
                              : inherited != null
                              ? '继承供应商默认配置'
                              : '未设置',
                          style: adapter == null && inherited == null
                              ? TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                )
                              : null,
                        ),
                        trailing: const SettingsIcon(
                          type: SettingsIconType.chevron,
                        ),
                        onTap: _saving ? null : _openAdapter,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _label('上下文压缩'),
                    Material(
                      color: settingsFieldColor(context),
                      borderRadius: BorderRadius.circular(24),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        minTileHeight: settingsCardHeight,
                        contentPadding: settingsCardPadding,
                        title: Text(
                          contextOverride == null
                              ? '继承默认 ${defaultPercent}% · 约 ${limits.compactThreshold} token'
                              : '此模型单独设置 · ${limits.compactPercent}% · 约 ${limits.compactThreshold} token',
                        ),
                        trailing: const SettingsIcon(
                          type: SettingsIconType.chevron,
                        ),
                        onTap: _saving ? null : _openContext,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 15,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Widget _nameField(
    TextEditingController controller,
    String hint,
    int maxLength,
  ) => TextField(
    controller: controller,
    enabled: !_saving,
    maxLength: maxLength,
    autocorrect: false,
    enableSuggestions: false,
    style: const TextStyle(fontSize: 16),
    decoration: InputDecoration(
      hintText: hint,
      counterText: '',
      filled: true,
      fillColor: settingsFieldColor(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: BorderSide.none,
      ),
    ),
  );
}
