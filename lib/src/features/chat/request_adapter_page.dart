import 'dart:convert';
import 'package:flutter/material.dart';
import '../../domain/model_provider.dart';
import '../../domain/request_adapter.dart';
import '../../providers/request_adapter_runner.dart';
import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import '../../scheduling/task_unsaved_dialog.dart';
import 'chat_controller.dart';
import 'glass_surface.dart';
import 'question_icon.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'choice_sheet.dart';

class RequestAdapterPage extends StatefulWidget {
  const RequestAdapterPage({
    super.key,
    required this.controller,
    required this.service,
    this.initialModel,
    this.readOnly = false,
  });
  final ChatController controller;
  final ModelService service;
  final String? initialModel;
  final bool readOnly;
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
  late String _scope = widget.initialModel ?? '';
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
    _load(_scope);
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

  Future<void> _protocolPicker() async {
    final choice = await showChoiceSheet<String>(
      context,
      title: '接口协议',
      selected: _protocol?.name ?? '',
      choices: [
        (value: '', label: '跟随供应商'),
        for (final protocol in ProviderProtocol.values)
          (value: protocol.name, label: protocol.label),
      ],
    );
    if (choice != null && mounted) {
      setState(() {
        _protocol = choice.isEmpty
            ? null
            : ProviderProtocol.values.byName(choice);
        _capture();
      });
    }
  }

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

  Widget _choice(String label, VoidCallback onTap) => Material(
    color: settingsFieldColor(context),
    borderRadius: BorderRadius.circular(26),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
            const SizedBox(width: 12),
            const SettingsIcon(type: SettingsIconType.chevron),
          ],
        ),
      ),
    ),
  );

  Widget _note(String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 14,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

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
          modelPurposes: old.details?.modelPurposes ?? const {},
          modelReasoning: old.details?.modelReasoning ?? const {},
          balance: old.details?.balance,
          icon: old.details?.icon,
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
  Widget build(BuildContext context) {
    if (widget.readOnly) {
      final adapter = _drafts[widget.initialModel ?? ''] ?? _drafts[''];
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: SettingsAppBar(
          title: '请求转换',
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
                    title: const Text('接口协议'),
                    subtitle: Text(adapter?.protocol?.label ?? '跟随供应商'),
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: const Text('JavaScript 请求转换'),
                    subtitle: SelectableText(
                      adapter?.script.isNotEmpty == true
                          ? adapter!.script
                          : '未设置',
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
        if (!didPop && !_busy) _leave();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: SettingsAppBar(
          title: '请求转换',
          onBack: _busy ? null : _leave,
          actions: [
            SettingsGlassActionSurface(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RoundAction(
                    label: '本地试运行',
                    icon: Icons.play_arrow_rounded,
                    iconWidget: const QuestionIcon(type: QuestionIconType.play),
                    onPressed: _busy ? null : _try,
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
                    onPressed: _busy ? null : _save,
                  ),
                ],
              ),
            ),
          ],
        ),
        body: SettingsPageBody(
          child: AbsorbPointer(
            absorbing: _busy,
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
                    if (widget.initialModel == null) ...[
                      _label('适用范围'),
                      _choice(
                        _custom
                            ? '其他模型名称'
                            : _scope.isEmpty
                            ? '供应商默认'
                            : _scope,
                        _scopePicker,
                      ),
                    ],
                    if (_custom) ...[
                      const SizedBox(height: 24),
                      _label('模型名称'),
                      TextField(
                        controller: _model,
                        maxLength: 200,
                        style: const TextStyle(fontSize: 16),
                        decoration: _fieldDecoration('输入模型名称'),
                        onChanged: (_) => setState(() => _preview = null),
                      ),
                    ],
                    if (widget.initialModel == null || _custom)
                      const SizedBox(height: 24),
                    _label('接口协议'),
                    _choice(_protocol?.label ?? '跟随供应商', _protocolPicker),
                    const SizedBox(height: 24),
                    _label('JavaScript 请求转换'),
                    TextField(
                      controller: _script,
                      minLines: 8,
                      maxLines: 20,
                      autocorrect: false,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                      ),
                      decoration: _fieldDecoration(
                        'request.body.max_completion_tokens = request.body.max_tokens;\ndelete request.body.max_tokens;\nreturn request;',
                      ),
                      onChanged: (_) => setState(_capture),
                    ),
                    const SizedBox(height: 16),
                    _note(
                      widget.initialModel == ''
                          ? '这里的转换会作为供应商默认值，未单独配置请求转换的模型会继承它。'
                          : '模型配置会覆盖供应商默认配置。留空脚本并选择跟随供应商，可移除当前模型的覆盖。',
                    ),
                    if (widget.initialModel?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => setState(() {
                            _script.clear();
                            _protocol = null;
                            _capture();
                          }),
                          child: const Text('恢复继承'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _note(
                      '脚本接收包含 model、path、body 的 request，返回 {path, body}；不能访问密钥、网络或文件。',
                    ),
                    const SizedBox(height: 12),
                    _note('试运行使用模拟请求，不会调用模型。'),
                    if (_preview != null) ...[
                      const SizedBox(height: 24),
                      Material(
                        color: settingsFieldColor(context),
                        borderRadius: BorderRadius.circular(26),
                        clipBehavior: Clip.antiAlias,
                        child: ExpansionTile(
                          title: const Text('查看转换结果'),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            18,
                            0,
                            18,
                            18,
                          ),
                          children: [
                            SelectableText(
                              const JsonEncoder.withIndent(
                                '  ',
                              ).convert(_preview),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
