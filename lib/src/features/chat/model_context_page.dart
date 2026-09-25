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
import 'settings_appearance.dart';
import 'settings_icon.dart';

class ModelContextPage extends StatefulWidget {
  const ModelContextPage({
    super.key,
    required this.controller,
    required this.service,
  });

  final ChatController controller;
  final ModelService service;

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
  late String _scope = widget.controller.modelSettings
      .profile(widget.service)
      .model;
  List<String> _usedModels = const [];
  bool _custom = false;
  bool _edited = false;
  bool _saving = false;
  bool _allowPop = false;

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
    _custom = _scope.isEmpty;
    _load(_scope);
    unawaited(_loadUsedModels());
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
    if (model.isEmpty &&
        _window.text.trim().isEmpty &&
        _percent.text.trim().isEmpty) {
      _edited = false;
      return true;
    }
    if (model.isEmpty || model.length > 200) {
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

  @override
  Widget build(BuildContext context) {
    final limits = _preview();
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) _leave();
      },
      child: Scaffold(
        appBar: SettingsAppBar(
          title: '上下文压缩',
          onBack: _saving ? null : _leave,
          actions: [
            SettingsGlassAction(
              label: '保存',
              icon: Icons.check_rounded,
              iconWidget: const SettingsIcon(type: SettingsIconType.check),
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
        body: AbsorbPointer(
          absorbing: _saving,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('模型'),
                subtitle: Text(_custom ? '其他模型名称' : _scope),
                trailing: const SettingsIcon(type: SettingsIconType.chevron),
                onTap: _pickModel,
              ),
              if (_custom)
                TextField(
                  controller: _model,
                  maxLength: 200,
                  decoration: const InputDecoration(labelText: '模型名称'),
                  onChanged: (_) => setState(() => _edited = true),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _window,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: '上下文窗口（token）',
                  hintText: limits?.contextWindow.toString() ?? '使用已知容量',
                  filled: true,
                  fillColor: settingsFieldColor(context),
                ),
                onChanged: (_) => setState(() => _edited = true),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _percent,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: '压缩阈值（输入预算百分比）',
                  hintText: '默认 80%',
                  filled: true,
                  fillColor: settingsFieldColor(context),
                ),
                onChanged: (_) => setState(() => _edited = true),
              ),
              const SizedBox(height: 16),
              if (limits != null)
                Text(
                  '当前约 ${limits.compactThreshold} token 触发压缩；'
                  '上下文窗口 ${limits.contextWindow} token'
                  '${limits.isEstimated ? '（估算）' : ''}。',
                ),
              const SizedBox(height: 8),
              const Text('输入预算会预留输出和工具空间。'),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() {
                    _window.clear();
                    _percent.clear();
                    _edited = true;
                  }),
                  child: const Text('恢复默认'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
