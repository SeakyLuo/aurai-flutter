import 'package:flutter/material.dart';

import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import '../../domain/model_provider.dart';
import '../../scheduling/task_unsaved_dialog.dart';
import 'chat_controller.dart';
import 'model_context_page.dart';
import 'model_reasoning_field.dart';
import 'request_adapter_page.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class DefaultModelSettingsPage extends StatefulWidget {
  const DefaultModelSettingsPage({
    super.key,
    required this.controller,
    required this.service,
    this.readOnly = false,
  });

  final ChatController controller;
  final ModelService service;
  final bool readOnly;

  @override
  State<DefaultModelSettingsPage> createState() =>
      _DefaultModelSettingsPageState();
}

class _DefaultModelSettingsPageState extends State<DefaultModelSettingsPage> {
  late ModelReasoning _savedReasoning = _config.reasoning;
  late ModelReasoning _reasoning = _savedReasoning;
  bool _saving = false;
  bool _allowPop = false;

  ModelConfig get _config =>
      widget.controller.modelSettings.profile(widget.service);

  void _notice(String message) => ScaffoldMessenger.of(
    context,
  ).showGlassSnackBar(SnackBar(content: Text(message)));

  Future<bool> _save() async {
    if (_reasoning == _savedReasoning) return true;
    setState(() => _saving = true);
    try {
      await widget.controller.saveConfig(
        _config.copyWith(reasoning: _reasoning),
        defaultService: widget.controller.modelSettings.activeService,
      );
      if (mounted) {
        setState(() => _savedReasoning = _reasoning);
        _notice('默认模型设置已保存');
      }
      return true;
    } on Object catch (error) {
      if (mounted) _notice('保存失败：${errorMessage(error)}');
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _leave() async {
    if (_reasoning == _savedReasoning) {
      setState(() => _allowPop = true);
      Navigator.pop(context);
      return;
    }
    final action = await showDialog<String>(
      context: context,
      builder: (_) => const TaskUnsavedDialog(description: '默认模型设置还有未保存的修改。'),
    );
    if (!mounted) return;
    if (action == 'save') {
      if (await _save() && mounted) {
        setState(() => _allowPop = true);
        Navigator.pop(context);
      }
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
          initialModel: '',
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
          initialModel: '',
          fixedModel: true,
          readOnly: widget.readOnly,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final adapters = _config.details?.requestAdapters;
    final percent = _config.details?.modelContextOverrides['']?.compactPercent;
    if (widget.readOnly) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: SettingsAppBar(
          title: '默认模型设置',
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
                    title: const Text('思考强度'),
                    subtitle: Text(_config.reasoning.label),
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                    ),
                    title: const Text('请求转换'),
                    subtitle: Text(
                      adapters?.containsKey('') == true ? '已设置' : '未设置',
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
                    subtitle: Text('压缩阈值 ${percent ?? 80}%'),
                    trailing: const SettingsIcon(
                      type: SettingsIconType.chevron,
                    ),
                    onTap: _openContext,
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
          title: '默认模型设置',
          onBack: _saving ? null : _leave,
          actions: [
            SettingsGlassAction(
              label: '保存',
              icon: Icons.check_rounded,
              iconWidget: const SettingsIcon(type: SettingsIconType.check),
              onPressed: _saving || _reasoning == _savedReasoning
                  ? null
                  : _save,
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Text(
                      '此供应商下的文本模型默认继承这些设置，单个模型可以覆盖。',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  ModelReasoningField(
                    service: widget.service,
                    model: _config.model,
                    baseUrl: _config.baseUrl,
                    value: _reasoning,
                    providerDefault: true,
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      title: Text(
                        adapters?.containsKey('') == true ? '已设置默认值' : '未设置',
                        style: adapters?.containsKey('') == true
                            ? null
                            : TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      title: Text('压缩阈值 ${percent ?? 80}%'),
                      trailing: const SettingsIcon(
                        type: SettingsIconType.chevron,
                      ),
                      onTap: _saving ? null : _openContext,
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
}
