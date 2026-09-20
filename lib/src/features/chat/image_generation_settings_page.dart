import '../../app/glass_notice.dart';
import 'package:flutter/material.dart';

import '../../domain/image_generation_config.dart';
import '../../domain/model_provider.dart';
import '../../providers/image_generation_client.dart';
import '../../scheduling/task_unsaved_dialog.dart';
import 'chat_controller.dart';
import 'choice_sheet.dart';
import 'model_provider_detail.dart';
import 'model_provider_icon.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class ImageGenerationSettingsPage extends StatefulWidget {
  const ImageGenerationSettingsPage({super.key, required this.controller});
  final ChatController controller;

  @override
  State<ImageGenerationSettingsPage> createState() =>
      _ImageGenerationSettingsPageState();
}

class _ImageGenerationSettingsPageState
    extends State<ImageGenerationSettingsPage> {
  late final _initial = widget.controller.imageGeneration;
  late ModelService _service =
      _initial?.service ??
      (widget.controller.modelSettings
              .profile(ModelService.openRouter)
              .isConfigured
          ? ModelService.openRouter
          : ModelService.qwen);
  late ImageGenerationModel? _model = _initial?.model;
  bool _loading = false;
  bool _saving = false;
  bool _allowPop = false;
  ImageGenerationClient? _client;
  bool get _locked => _loading || _saving;
  bool get _dirty =>
      _model?.id != _initial?.model.id ||
      (_model != null && _service != _initial?.service);
  ModelConfig get _account => widget.controller.modelSettings.profile(_service);

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }

  void _notice(String text) => ScaffoldMessenger.of(context).showGlassSnackBar(
    SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
  );

  void _leave() {
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _back() async {
    if (_locked) return;
    if (!_dirty) {
      _leave();
      return;
    }
    final action = await showDialog<String>(
      context: context,
      builder: (_) => const TaskUnsavedDialog(description: '图片生成设置还有未保存的修改。'),
    );
    if (!mounted) return;
    if (action == 'save') await _save();
    if (action == 'discard') _leave();
  }

  Future<void> _configure() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ModelProviderDetail(
          controller: widget.controller,
          service: _service,
          accountOnly: true,
          credentialsOnly: true,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _chooseService() async {
    final value = await showChoiceSheet<ModelService>(
      context,
      title: '生图服务商',
      selected: _service,
      choices: [
        for (final service in [ModelService.openRouter, ModelService.qwen])
          (value: service, label: service.label),
      ],
    );
    if (!mounted || value == null || value == _service) return;
    setState(() {
      _service = value;
      _model = null;
    });
  }

  Future<void> _chooseModel() async {
    if (!_account.isConfigured) await _configure();
    if (!mounted || !_account.isConfigured) return;
    setState(() => _loading = true);
    final client = ImageGenerationClient();
    _client = client;
    try {
      final models = await client.models(_account);
      if (!mounted) return;
      if (models.isEmpty) {
        _notice('没有可用的生图模型，请检查服务商配置');
        return;
      }
      final selected = await showChoiceSheet<String>(
        context,
        title: '选择生图模型',
        selected: _model?.id ?? '',
        choices: [
          for (final model in models) (value: model.id, label: model.name),
        ],
      );
      if (!mounted || selected == null) return;
      setState(() => _model = models.firstWhere((m) => m.id == selected));
    } on ModelProviderException catch (error) {
      if (mounted) _notice(error.message);
    } on Object {
      if (mounted) _notice('无法获取生图模型，请检查网络和服务商配置后重试');
    } finally {
      client.close();
      _client = null;
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_model == null) {
      _notice('请先选择生图模型');
      return;
    }
    if (!_account.isConfigured) {
      await _configure();
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.controller.saveImageGeneration(
        ImageGenerationConfig(service: _service, model: _model!),
      );
      if (!mounted) return;
      _notice('图片生成设置已保存');
      _leave();
    } on Object {
      if (mounted) _notice('保存失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _back();
    },
    child: Scaffold(
      appBar: SettingsAppBar(
        title: '图片生成',
        onBack: _locked ? null : _back,
        actions: [
          SettingsGlassAction(
            label: '保存',
            icon: Icons.check_rounded,
            onPressed: _locked || _model == null ? null : _save,
            iconWidget: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const SettingsIcon(type: SettingsIconType.check),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _row(
                  title: '服务商',
                  subtitle: _service.label,
                  leading: ModelProviderIcon(service: _service),
                  onTap: _locked ? null : _chooseService,
                ),
                const SizedBox(height: 12),
                _row(
                  title: '生图模型',
                  subtitle: _model?.name ?? '选择模型',
                  loading: _loading,
                  onTap: _locked ? null : _chooseModel,
                ),
                const SizedBox(height: 12),
                _row(
                  title: '服务商配置',
                  subtitle: _account.isConfigured
                      ? '使用已保存的密钥和服务地址'
                      : '配置密钥和服务地址',
                  onTap: _locked ? null : _configure,
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '所有 AI 共用此生图模型，聊天模型保持不变。生成的图片会保存为文件，可用于后续编辑或发送。'
                    '${_model == null
                        ? ''
                        : _model!.supportsReference
                        ? '\n支持文字生成和参考图编辑。'
                        : '\n此模型支持文字生成，不支持参考图编辑。'}',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
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
  );

  Widget _row({
    required String title,
    required String subtitle,
    Widget? leading,
    bool loading = false,
    VoidCallback? onTap,
  }) => Material(
    color: settingsFieldColor(context),
    borderRadius: BorderRadius.circular(24),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      leading: leading,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: loading
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const SettingsIcon(type: SettingsIconType.chevron),
      onTap: onTap,
    ),
  );
}
