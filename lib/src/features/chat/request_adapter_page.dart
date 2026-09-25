import 'dart:convert';
import 'package:flutter/material.dart';
import '../../domain/model_provider.dart';
import '../../domain/request_adapter.dart';
import '../../providers/request_adapter_runner.dart';
import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import '../../scheduling/task_unsaved_dialog.dart';
import 'chat_controller.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'choice_sheet.dart';

class RequestAdapterPage extends StatefulWidget {
  const RequestAdapterPage({
    super.key,
    required this.controller,
    required this.service,
  });
  final ChatController controller;
  final ModelService service;
  @override
  State<RequestAdapterPage> createState() => _RequestAdapterPageState();
}

class _RequestAdapterPageState extends State<RequestAdapterPage> {
  late final _initial = {
    ...?widget.controller.modelSettings
        .profile(widget.service)
        .details
        ?.requestAdapters,
  };
  late final Map<String, RequestAdapter> _drafts = Map.of(_initial);
  final _script = TextEditingController();
  final _model = TextEditingController();
  String _scope = '';
  ProviderProtocol? _protocol;
  bool _custom = false, _busy = false, _allowPop = false;
  Map<String, Object?>? _preview;
  String get _key => _custom ? _model.text.trim() : _scope;
  bool get _dirty =>
      (_custom &&
          _key.isEmpty &&
          (_script.text.trim().isNotEmpty || _protocol != null)) ||
      jsonEncode(_drafts.map((k, v) => MapEntry(k, v.toJson()))) !=
          jsonEncode(_initial.map((k, v) => MapEntry(k, v.toJson())));

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _script.dispose();
    _model.dispose();
    super.dispose();
  }

  void _load(String key) {
    final adapter = _drafts[key];
    _script.text = adapter?.script ?? '';
    _protocol = adapter?.protocol;
    _preview = null;
  }

  void _capture() {
    if (_custom && _key.isEmpty) return;
    if (_script.text.trim().isEmpty && _protocol == null) {
      _drafts.remove(_key);
    } else {
      _drafts[_key] = RequestAdapter(protocol: _protocol, script: _script.text);
    }
    _preview = null;
  }

  void _notice(Object message) => ScaffoldMessenger.of(
    context,
  ).showGlassSnackBar(SnackBar(content: Text('$message')));
  Future<void> _scopePicker() async {
    final config = widget.controller.modelSettings.profile(widget.service);
    final selected = await showChoiceSheet<String>(
      context,
      title: '适用范围',
      selected: _scope,
      choices: [
        (value: '', label: '供应商默认'),
        for (final model in {
          ...config.savedModels,
          if (config.model.isNotEmpty) config.model,
          ..._drafts.keys.where((k) => k.isNotEmpty),
        })
          (value: model, label: model),
        (value: '__custom__', label: '其他模型名称'),
      ],
    );
    if (selected == null || !mounted) return;
    setState(() {
      _capture();
      _custom = selected == '__custom__';
      _scope = selected;
      if (_custom) _model.clear();
      _load(_custom ? '' : selected);
      if (_custom) {
        _script.clear();
        _protocol = null;
      }
    });
  }

  Future<void> _try() async {
    _capture();
    if (_custom && _key.isEmpty) {
      _notice('请填写模型名称');
      return;
    }
    setState(() => _busy = true);
    try {
      final old = widget.controller.modelSettings.profile(widget.service);
      final config = old.copyWith(
        model: _key.isEmpty ? old.model : _key,
        details: ProviderDetails(
          modelContextOverrides: old.details?.modelContextOverrides ?? const {},
          name: old.displayName,
          website: old.website,
          protocol: old.protocol,
          models: old.savedModels,
          autoSyncModels: old.autoSyncModels,
          requestAdapters: _drafts,
        ),
      );
      final result = await previewRequestAdapter(config);
      if (mounted) setState(() => _preview = result);
    } catch (error) {
      if (mounted) _notice(errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    _capture();
    if (_custom && _key.isEmpty) {
      _notice('请填写模型名称');
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.controller.saveRequestAdapters(
        widget.service,
        _drafts,
        _initial,
      );
      if (mounted) {
        setState(() => _allowPop = true);
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) _notice(errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    _capture();
    if (!_dirty) {
      setState(() => _allowPop = true);
      Navigator.pop(context);
      return;
    }
    final action = await showDialog<String>(
      context: context,
      builder: (_) => const TaskUnsavedDialog(description: '请求转换还有未保存的修改。'),
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
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && !_busy) _leave();
    },
    child: Scaffold(
      appBar: SettingsAppBar(
        title: '请求转换',
        onBack: _busy ? null : _leave,
        actions: [
          SettingsGlassAction(
            label: '保存',
            icon: Icons.check_rounded,
            iconWidget: const SettingsIcon(type: SettingsIconType.check),
            onPressed: _busy ? null : _save,
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('适用范围'),
              subtitle: Text(
                _custom
                    ? '其他模型名称'
                    : _scope.isEmpty
                    ? '供应商默认'
                    : _scope,
              ),
              trailing: const SettingsIcon(type: SettingsIconType.chevron),
              onTap: _scopePicker,
            ),
            if (_custom)
              TextField(
                controller: _model,
                decoration: const InputDecoration(labelText: '模型名称'),
                onChanged: (_) => setState(() => _preview = null),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('接口协议'),
              subtitle: Text(_protocol?.label ?? '跟随供应商'),
              trailing: const SettingsIcon(type: SettingsIconType.chevron),
              onTap: () async {
                final choice = await showChoiceSheet<String>(
                  context,
                  title: '接口协议',
                  selected: _protocol?.name ?? '',
                  choices: [
                    (value: '', label: '跟随供应商'),
                    for (final p in ProviderProtocol.values)
                      (value: p.name, label: p.label),
                  ],
                );
                if (choice != null && mounted)
                  setState(() {
                    _protocol = choice.isEmpty
                        ? null
                        : ProviderProtocol.values.byName(choice);
                    _capture();
                  });
              },
            ),
            const Text(
              '模型配置覆盖供应商默认配置。脚本留空且协议跟随供应商时，移除该覆盖并恢复继承。只选择协议时，不执行供应商脚本。',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _script,
              minLines: 8,
              maxLines: 20,
              autocorrect: false,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
              decoration: InputDecoration(
                labelText: 'JavaScript 请求转换',
                hintText:
                    'request.body.max_completion_tokens = request.body.max_tokens;\ndelete request.body.max_tokens;\nreturn request;',
                filled: true,
                fillColor: settingsFieldColor(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => setState(_capture),
            ),
            const SizedBox(height: 12),
            const Text(
              '输入 request 包含 model、path、body，返回 {path, body}。无密钥、网络或文件访问。切换协议请使用上方选项，不要仅修改路径。',
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: _try, child: const Text('本地试运行')),
            const Text('试运行使用模拟请求，不调用模型，不代表供应商兼容性验证通过。'),
            if (_preview != null)
              ExpansionTile(
                title: const Text('查看转换结果'),
                children: [
                  SelectableText(
                    const JsonEncoder.withIndent('  ').convert(_preview),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    ),
  );
}
