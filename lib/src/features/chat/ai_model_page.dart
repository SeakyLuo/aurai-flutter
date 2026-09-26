import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import '../../providers/model_catalog.dart';
import 'package:flutter/material.dart';
import '../../domain/ai_profile.dart';
import '../../domain/model_provider.dart';
import 'chat_controller.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'choice_sheet.dart';
import 'model_balance_tile.dart';
import 'model_settings_sheet.dart';
import 'model_reasoning_field.dart';
import '../../scheduling/task_unsaved_dialog.dart';

class AiModelPage extends StatefulWidget {
  const AiModelPage({
    super.key,
    required this.controller,
    required this.profile,
  });
  final ChatController controller;
  final AiProfile profile;
  @override
  State<AiModelPage> createState() => _AiModelPageState();
}

class _AiModelPageState extends State<AiModelPage> {
  late ModelService _service = widget.controller
      .aiConfig(widget.profile)
      .service;
  late final _model = TextEditingController(
    text: widget.controller.aiConfig(widget.profile).model,
  );
  late final _url = TextEditingController(
    text: widget.controller.aiConfig(widget.profile).baseUrl,
  );
  late ModelReasoning _reasoning = widget.profile.preferences.reasoning;
  bool _saving = false,
      _changed = false,
      _leaveAllowed = false,
      _loading = false;
  ModelCatalog? _catalog;
  @override
  void dispose() {
    _catalog?.close();
    _model.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_model.text.isEmpty) {
      await _selectModel();
      if (!mounted || _model.text.isEmpty) return;
    }
    setState(() => _saving = true);
    try {
      await widget.controller.saveAi(
        widget.profile.copyWith(
          preferences: widget.profile.preferences.copyWith(
            reasoning: _reasoning,
          ),
          modelSelection: AiModelSelection(
            provider: _service,
            model: _model.text.trim(),
            baseUrl: _url.text.trim(),
          ),
        ),
      );
      if (mounted) {
        setState(() {
          _changed = false;
          _leaveAllowed = true;
        });
        Navigator.pop(context);
      }
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showGlassSnackBar(
          SnackBar(content: Text('保存失败，请重试：${errorMessage(error)}')),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _leave() async {
    final action = await showDialog<String>(
      context: context,
      builder: (_) => const TaskUnsavedDialog(description: '模型设置还有未保存的修改。'),
    );
    if (!mounted || action == null) return;
    if (action == 'save') {
      await _save();
    } else {
      setState(() => _leaveAllowed = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _leaveAllowed || (!_changed && !_saving),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && !_saving) _leave();
    },
    child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        title: '模型',
        onBack: () => Navigator.maybePop(context),
        actions: [
          SettingsGlassAction(
            label: '保存',
            icon: Icons.check_rounded,
            iconWidget: const SettingsIcon(type: SettingsIconType.check),
            onPressed: _saving || _loading ? null : _save,
          ),
        ],
      ),
      body: SettingsPageBody(
        child: ListView(
          padding: settingsPagePadding(context, const EdgeInsets.all(16)),
          children: [
            _label('供应商'),
            _choice(
              widget.controller.modelSettings.profile(_service).displayName,
              _saving || _loading
                  ? null
                  : () async {
                      final value = await showChoiceSheet<ModelService>(
                        context,
                        title: '供应商',
                        selected: _service,
                        choices: [
                          for (final service
                              in widget.controller.modelSettings.profiles.keys
                                  .where(
                                    (service) => widget.controller.modelSettings
                                        .profile(service)
                                        .protocol
                                        .supportsChatModels,
                                  ))
                            (
                              value: service,
                              label: widget.controller.modelSettings
                                  .profile(service)
                                  .displayName,
                            ),
                        ],
                      );
                      if (!mounted || value == null || value == _service)
                        return;
                      setState(() {
                        _service = value;
                        _reasoning = ModelReasoning.inherit;
                        _changed = true;
                        _model.clear();
                        _url.text = widget.controller.modelSettings
                            .profile(value)
                            .baseUrl;
                      });
                    },
            ),
            const SizedBox(height: 16),
            _label('模型名称'),
            _choice(
              _model.text.isEmpty ? '选择模型' : modelDisplayName(_model.text),
              _saving || _loading ? null : _selectModel,
              loading: _loading,
            ),
            ModelReasoningField(
              service: _service,
              model: _model.text,
              baseUrl: _url.text,
              value: _reasoning,
              inheritedValue: widget.controller.modelSettings
                  .profile(_service)
                  .reasoningFor(_model.text),
              onChanged: _saving || _loading
                  ? null
                  : (value) => setState(() {
                      _reasoning = value;
                      _changed = true;
                    }),
            ),
            const SizedBox(height: 16),
            _label('账户余额'),
            ModelBalanceTile(
              key: ValueKey((_service, _url.text)),
              config: ModelConfig(
                service: _service,
                details: widget.controller.modelSettings
                    .profile(_service)
                    .details,
                apiKey: widget.controller.modelSettings
                    .profile(_service)
                    .apiKey,
                model: _model.text,
                baseUrl: _url.text,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  void _notice(String text) => ScaffoldMessenger.of(
    context,
  ).showGlassSnackBar(SnackBar(content: Text(text)));

  Future<void> _selectModel() async {
    if (_loading) return;
    setState(() => _loading = true);
    final catalog = ModelCatalog();
    _catalog = catalog;
    try {
      var profile = widget.controller.modelSettings.profile(_service);
      if (profile.apiKey.isEmpty) {
        final saved = await ModelSettingsSheet.show(
          context,
          controller: widget.controller,
          continueAfterSave: false,
          accountOnly: true,
          initialService: _service,
        );
        if (!mounted || !saved) return;
        profile = widget.controller.modelSettings.profile(_service);
        if (profile.apiKey.isEmpty) return;
      }
      final availableModels = profile.autoSyncModels
          ? await catalog.loadFor(profile, textOnly: true)
          : profile.savedModels;
      final models = [
        for (final model in availableModels)
          if (profile.details?.modelPurposes[model]?.contains(
                ModelPurpose.text,
              ) ??
              true)
            model,
      ];
      if (!mounted) return;
      if (models.isEmpty) {
        _notice('没有可用的文本模型，请到供应商的模型管理中设置用途');
        return;
      }
      final value = await showChoiceSheet<String>(
        context,
        title: '模型名称',
        selected: _model.text,
        choices: [
          for (final model in models)
            (value: model, label: modelDisplayName(model)),
        ],
      );
      if (!mounted || value == null) return;
      setState(() {
        if (_model.text != value) _reasoning = ModelReasoning.inherit;
        _model.text = value;
        _url.text = profile.baseUrl;
        _changed = true;
      });
    } on ModelProviderException catch (error) {
      if (mounted) _notice(error.message);
    } on Object catch (error) {
      if (mounted) _notice('无法获取模型，请检查设置中的供应商配置：${errorMessage(error)}');
    } finally {
      catalog.close();
      _catalog = null;
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _label(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 15,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
  Widget _choice(String value, VoidCallback? onTap, {bool loading = false}) =>
      Material(
        color: settingsFieldColor(context),
        borderRadius: BorderRadius.circular(26),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          title: Text(value, style: const TextStyle(fontSize: 15)),
          trailing: loading
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const RotatedBox(
                  quarterTurns: 1,
                  child: SettingsIcon(type: SettingsIconType.chevron),
                ),
          onTap: onTap,
        ),
      );
}
