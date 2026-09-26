import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import '../../domain/model_provider.dart';
import '../../providers/model_context_limits.dart';
import '../../scheduling/task_unsaved_dialog.dart';
import 'chat_controller.dart';
import 'choice_sheet.dart';
import 'glass_surface.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class ModelContextPage extends StatefulWidget {
  const ModelContextPage({
    super.key,
    required this.controller,
    required this.service,
    this.initialModel,
    this.fixedModel = false,
    this.readOnly = false,
  });

  final ChatController controller;
  final ModelService service;
  final String? initialModel;
  final bool fixedModel;
  final bool readOnly;

  @override
  State<ModelContextPage> createState() => _ModelContextPageState();
}

class _ModelContextPageState extends State<ModelContextPage> {
  late final _initial = {
    ...?widget.controller.modelSettings
        .profile(widget.service)
        .details
        ?.modelContextOverrides,
  };
  late final Map<String, ModelContextOverride> _drafts = Map.of(_initial);
  final _model = TextEditingController();
  final _window = TextEditingController();
  final _percent = TextEditingController();
  late String _scope =
      widget.initialModel ??
      widget.controller.modelSettings.profile(widget.service).model;
  List<String> _usedModels = const [];
  bool _custom = false;
  bool _edited = false;
  bool _saving = false;
  bool _allowPop = false;

  bool get _providerDefault => widget.fixedModel && widget.initialModel == '';

  String get _selectedModel => _custom ? _model.text.trim() : _scope;
  bool get _dirty =>
      _edited ||
      jsonEncode(_drafts.map((key, value) => MapEntry(key, value.toJson()))) !=
          jsonEncode(
            _initial.map((key, value) => MapEntry(key, value.toJson())),
          );

  @override
  void initState() {
    super.initState();
    _custom = _scope.isEmpty && !widget.fixedModel;
    _load(_scope);
    if (!widget.fixedModel) unawaited(_loadUsedModels());
  }

  Future<void> _loadUsedModels() async {
    try {
      final used = await widget.controller.usedModels(ModelPurpose.text);
      if (mounted) {
        setState(
          () => _usedModels = [
            for (final item in used)
              if (item.model.service == widget.service) item.model.model,
          ],
        );
      }
    } on Object catch (error) {
      if (mounted) _notice('无法读取已使用模型：${errorMessage(error)}');
    }
  }

  @override
  void dispose() {
    _model.dispose();
    _window.dispose();
    _percent.dispose();
    super.dispose();
  }

  void _load(String model) {
    final value = _drafts[model];
    _window.text = value?.contextWindow?.toString() ?? '';
    _percent.text = value?.compactPercent?.toString() ?? '';
    _edited = false;
  }

  void _notice(String text) => ScaffoldMessenger.of(
    context,
  ).showGlassSnackBar(SnackBar(content: Text(text)));

  bool _capture() {
    final model = _selectedModel;
    if (!_providerDefault &&
        model.isEmpty &&
        _window.text.trim().isEmpty &&
        _percent.text.trim().isEmpty) {
      _edited = false;
      return true;
    }
    if (!_providerDefault && (model.isEmpty || model.length > 200)) {
      _notice('请输入有效的模型名称');
      return false;
    }
    final windowText = _window.text.trim();
    final percentText = _percent.text.trim();
    final window = windowText.isEmpty ? null : int.tryParse(windowText);
    final percent = percentText.isEmpty ? null : int.tryParse(percentText);
    if (windowText.isNotEmpty &&
        (window == null || window < 32768 || window > 2000000)) {
      _notice('上下文窗口需在 32K–2M token 之间');
      return false;
    }
    if (percentText.isNotEmpty &&
        (percent == null || percent < 65 || percent > 95)) {
      _notice('压缩阈值需在 65%–95% 之间');
      return false;
    }
    if (window == null && percent == null) {
      _drafts.remove(model);
    } else {
      _drafts[model] = ModelContextOverride(
        contextWindow: window,
        compactPercent: percent,
      );
    }
    _edited = false;
    return true;
  }

  Future<void> _pickModel() async {
    final config = widget.controller.modelSettings.profile(widget.service);
    final choice = await showChoiceSheet<String>(
      context,
      title: '选择模型',
      selected: _custom ? '__custom__' : _scope,
      choices: [
        for (final model in {
          if (_scope.isNotEmpty) _scope,
          if (config.model.isNotEmpty) config.model,
          ..._usedModels,
          ...config.savedModels,
          ..._drafts.keys,
          if (widget.controller.modelSettings.modelDefaults[ModelPurpose.text]
              case final selection? when selection.service == widget.service)
            selection.model,
        })
          (value: model, label: model),
        (value: '__custom__', label: '其他模型名称'),
      ],
    );
    if (!mounted || choice == null) return;
    if (!_capture()) return;
    setState(() {
      _custom = choice == '__custom__';
      _scope = _custom ? '' : choice;
      _model.clear();
      _load(_scope);
    });
  }

  ModelContextLimits? _preview() {
    final model = _selectedModel;
    if (model.isEmpty) return null;
    final windowText = _window.text.trim();
    final percentText = _percent.text.trim();
    final window = windowText.isEmpty ? null : int.tryParse(windowText);
    final percent = percentText.isEmpty ? null : int.tryParse(percentText);
    if ((windowText.isNotEmpty &&
            (window == null || window < 32768 || window > 2000000)) ||
        (percentText.isNotEmpty &&
            (percent == null || percent < 65 || percent > 95))) {
      return null;
    }
    final config = widget.controller.modelSettings.profile(widget.service);
    final draft = {..._drafts};
    draft[model] = ModelContextOverride(
      contextWindow: window,
      compactPercent: percent,
    );
    return ModelContextLimits.previewForConfig(
      config.copyWith(
        model: model,
        details: ProviderDetails(
          name: config.displayName,
          website: config.website,
          protocol: config.protocol,
          models: config.savedModels,
          autoSyncModels: config.autoSyncModels,
          requestAdapters: config.details?.requestAdapters ?? const {},
          modelPurposes: config.details?.modelPurposes ?? const {},
          modelReasoning: config.details?.modelReasoning ?? const {},
          balance: config.details?.balance,
          icon: config.details?.icon,
          modelContextOverrides: draft,
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_capture()) return;
    setState(() => _saving = true);
    try {
      final config = widget.controller.modelSettings.profile(widget.service);
      await widget.controller.saveConfig(
        config.copyWith(
          details: ProviderDetails(
            name: config.displayName,
            website: config.website,
            protocol: config.protocol,
            models: config.savedModels,
            autoSyncModels: config.autoSyncModels,
            requestAdapters: config.details?.requestAdapters ?? const {},
            modelPurposes: config.details?.modelPurposes ?? const {},
            modelReasoning: config.details?.modelReasoning ?? const {},
            balance: config.details?.balance,
            icon: config.details?.icon,
            modelContextOverrides: _drafts,
          ),
        ),
        defaultService: widget.controller.modelSettings.activeService,
      );
      if (!mounted) return;
      _notice('上下文压缩设置已保存');
      setState(() => _allowPop = true);
      Navigator.pop(context, true);
    } on Object catch (error) {
      if (mounted) _notice('保存失败：${errorMessage(error)}');
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
      builder: (_) => const TaskUnsavedDialog(description: '上下文压缩设置还有未保存的修改。'),
    );
    if (!mounted) return;
    if (action == 'save') {
      await _save();
    } else if (action == 'discard') {
      setState(() => _allowPop = true);
      Navigator.pop(context);
    }
  }

  void _reset() => setState(() {
    _window.clear();
    _percent.clear();
    _edited = true;
  });

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 15,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  InputDecoration _fieldDecoration(String hint) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(26),
      borderSide: BorderSide.none,
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 15,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      filled: true,
      fillColor: settingsFieldColor(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      border: border,
      enabledBorder: border,
      focusedBorder: border,
    );
  }

  Widget _modelChoice() => Material(
    color: settingsFieldColor(context),
    borderRadius: BorderRadius.circular(26),
    child: InkWell(
      onTap: _pickModel,
      borderRadius: BorderRadius.circular(26),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _custom ? '其他模型名称' : _scope,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            const SettingsIcon(type: SettingsIconType.chevron),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final limits = _preview();
    if (widget.readOnly) {
      final value = _drafts[_scope];
      final inherited =
          widget.controller.modelSettings
              .profile(widget.service)
              .details
              ?.modelContextOverrides['']
              ?.compactPercent ??
          80;
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: SettingsAppBar(
          title: '上下文压缩',
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
                  if (!_providerDefault)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      title: const Text('上下文窗口（token）'),
                      subtitle: Text(
                        value?.contextWindow?.toString() ??
                            limits?.contextWindow.toString() ??
                            '使用已知容量',
                      ),
                    ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: const Text('压缩阈值'),
                    subtitle: Text(
                      '${value?.compactPercent ?? inherited}%'
                      '${!_providerDefault && value?.compactPercent == null ? ' · 继承默认设置' : ''}',
                    ),
                  ),
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
          title: '上下文压缩',
          onBack: _saving ? null : _leave,
          actions: [
            SettingsGlassActionSurface(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RoundAction(
                    label: _providerDefault ? '恢复默认' : '恢复继承',
                    icon: Icons.restore_rounded,
                    iconWidget: const SettingsIcon(
                      type: SettingsIconType.reset,
                    ),
                    onPressed:
                        _saving ||
                            (_window.text.isEmpty && _percent.text.isEmpty)
                        ? null
                        : _reset,
                  ),
                  SizedBox(
                    height: 18,
                    child: VerticalDivider(
                      width: 1,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  RoundAction(
                    label: '保存',
                    icon: Icons.check_rounded,
                    iconWidget: const SettingsIcon(
                      type: SettingsIconType.check,
                    ),
                    onPressed: _saving ? null : _save,
                  ),
                ],
              ),
            ),
          ],
        ),
        body: SettingsPageBody(
          child: AbsorbPointer(
            absorbing: _saving,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: settingsPagePadding(
                    context,
                    const EdgeInsets.fromLTRB(16, 20, 16, 32),
                  ),
                  children: [
                    if (!widget.fixedModel) ...[_label('模型'), _modelChoice()],
                    if (_custom && !widget.fixedModel) ...[
                      const SizedBox(height: 24),
                      _label('模型名称'),
                      TextField(
                        controller: _model,
                        maxLength: 200,
                        style: const TextStyle(fontSize: 16),
                        decoration: _fieldDecoration('输入模型名称'),
                        onChanged: (_) => setState(() => _edited = true),
                      ),
                    ],
                    if (!_providerDefault) ...[
                      const SizedBox(height: 24),
                      _label('上下文窗口（token）'),
                      TextField(
                        controller: _window,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(fontSize: 16),
                        decoration: _fieldDecoration(
                          limits?.contextWindow.toString() ?? '使用已知容量',
                        ),
                        onChanged: (_) => setState(() => _edited = true),
                      ),
                    ],
                    if (!_providerDefault || !widget.fixedModel)
                      const SizedBox(height: 24),
                    _label('压缩阈值（%）'),
                    TextField(
                      controller: _percent,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(fontSize: 16),
                      decoration: _fieldDecoration(
                        _providerDefault
                            ? '默认 80'
                            : '继承默认 ${widget.controller.modelSettings.profile(widget.service).details?.modelContextOverrides['']?.compactPercent ?? 80}',
                      ),
                      onChanged: (_) => setState(() => _edited = true),
                    ),
                    if (limits != null) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Text(
                          '约 ${limits.compactThreshold} token 触发压缩'
                          '${limits.isEstimated ? '（窗口容量为估算值）' : ''}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Text(
                        _providerDefault
                            ? '此供应商下的文本模型默认继承该压缩阈值；每个模型按自己的上下文窗口计算。留空使用 80%。'
                            : '留空继承默认模型设置。压缩阈值可设置为 65%–95%，计算时会预留输出和工具空间。',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
