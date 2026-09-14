import '../../domain/error_message.dart';
import 'package:flutter/material.dart';
import '../../domain/model_provider.dart';
import '../../providers/model_catalog.dart';
import 'chat_controller.dart';
import 'choice_sheet.dart';
import 'delete_confirmation_dialog.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'model_balance_tile.dart';

class ModelSettingsSheet extends StatefulWidget {
  const ModelSettingsSheet({
    super.key,
    required this.controller,
    required this.continueAfterSave,
    this.accountOnly = false,
    this.initialService,
  });
  final ChatController controller;
  final bool continueAfterSave;
  final bool accountOnly;
  final ModelService? initialService;
  static Future<bool> show(
    BuildContext context, {
    required ChatController controller,
    required bool continueAfterSave,
    bool accountOnly = false,
    ModelService? initialService,
  }) async {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..removeCurrentSnackBar();
    return await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => ModelSettingsSheet(
              controller: controller,
              continueAfterSave: continueAfterSave,
              accountOnly: accountOnly,
              initialService: initialService,
            ),
          ),
        ) ??
        false;
  }

  @override
  State<ModelSettingsSheet> createState() => _ModelSettingsSheetState();
}

class _ModelSettingsSheetState extends State<ModelSettingsSheet> {
  final _key = TextEditingController();
  final _address = TextEditingController();
  final _drafts =
      <ModelService, ({String key, String address, String model})>{};
  late ModelService _service;
  late final ModelService _originalDefault =
      widget.controller.modelSettings.activeService;
  late ModelService _defaultService = _originalDefault;
  late String _model;
  var _obscure = true;
  var _saving = false;
  var _loading = false;
  var _allowPop = false;
  ModelCatalog? _catalog;
  ModelConfig get _saved => widget.controller.modelSettings.profile(_service);
  bool get _locked => _saving || _loading;
  bool get _currentDirty =>
      _apiKey != _saved.apiKey ||
      _address.text != _saved.baseUrl ||
      _model != _saved.model;
  bool get _dirty =>
      _currentDirty ||
      _defaultService != _originalDefault ||
      _drafts.keys.any((service) => service != _service);

  void _keepDraft() {
    if (_currentDirty) {
      _drafts[_service] = (
        key: _key.text,
        address: _address.text,
        model: _model,
      );
    } else {
      _drafts.remove(_service);
    }
  }

  @override
  void initState() {
    super.initState();
    final config = widget.controller.config;
    _loadProfile(
      widget.initialService ??
          (widget.accountOnly
              ? widget.controller.modelSettings.activeService
              : config.service),
    );
    if (!widget.accountOnly) {
      _model = config.model;
      _address.text = config.baseUrl;
    }
    _key.addListener(_changed);
    _address.addListener(_changed);
  }

  void _changed() => setState(() {});
  void _loadProfile(ModelService service) {
    _service = service;
    final draft = _drafts[service];
    _key.text = draft?.key ?? _saved.apiKey;
    _address.text = draft?.address ?? _saved.baseUrl;
    _model = draft?.model ?? _saved.model;
    _obscure = true;
  }

  @override
  void dispose() {
    _catalog?.close();
    _key.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || (!_locked && !_dirty),
    onPopInvokedWithResult: (didPop, result) async {
      if (!didPop && !_locked && await _discardChanges() && mounted) {
        setState(() => _allowPop = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      }
    },
    child: Scaffold(
      appBar: SettingsAppBar(
        title: widget.accountOnly ? '服务商账号' : '模型设置',
        onBack: _locked ? null : () => Navigator.maybePop(context),
        actions: [
          SettingsGlassAction(
            label: _saving ? '正在保存' : '保存',
            icon: Icons.check_rounded,
            onPressed: _locked ? null : _save,
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
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                const _Label('模型供应商'),
                _ModelChoice(
                  label: _service.label,
                  onTap: _locked ? null : _selectService,
                ),
                const SizedBox(height: 32),
                const _Label('API 密钥'),
                TextField(
                  controller: _key,
                  enabled: !_locked,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(fontSize: 16),
                  decoration: _fieldDecoration(
                    hint: _saved.isConfigured ? '已保存密钥 · 留空保持不变' : '粘贴 API 密钥',
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Center(
                        widthFactor: 1,
                        heightFactor: 1,
                        child: SizedBox.square(
                          dimension: 40,
                          child: IconButton(
                            style: IconButton.styleFrom(
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(8),
                            ),
                            onPressed: _locked
                                ? null
                                : () => setState(() => _obscure = !_obscure),
                            tooltip: _obscure ? '显示密钥' : '隐藏密钥',
                            icon: SettingsIcon(
                              type: _obscure
                                  ? SettingsIconType.eye
                                  : SettingsIconType.eyeOff,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const _Label('服务地址'),
                TextField(
                  controller: _address,
                  enabled: !_locked,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(fontSize: 16),
                  decoration: _fieldDecoration(hint: _service.defaultBaseUrl),
                ),
                const SizedBox(height: 32),
                const _Label('使用的模型'),
                _ModelChoice(
                  label: modelDisplayName(_model),
                  loading: _loading,
                  onTap: _locked ? null : _selectModel,
                ),
                const SizedBox(height: 12),
                Material(
                  color: settingsFieldColor(context),
                  borderRadius: BorderRadius.circular(26),
                  clipBehavior: Clip.antiAlias,
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                    title: const Text('设为默认', style: TextStyle(fontSize: 16)),
                    value: _defaultService == _service,
                    onChanged:
                        _locked ||
                            (_service == _originalDefault &&
                                _defaultService == _originalDefault)
                        ? null
                        : (value) => setState(() {
                            _defaultService = value
                                ? _service
                                : _originalDefault;
                          }),
                  ),
                ),
                if (_saved.isConfigured) ...[
                  const SizedBox(height: 32),
                  const _Label('账户余额'),
                  ModelBalanceTile(
                    key: ValueKey(_service),
                    config: ModelConfig(
                      service: _service,
                      apiKey: _apiKey,
                      model: _model,
                      baseUrl: _address.text.trim(),
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
  InputDecoration _fieldDecoration({required String hint, Widget? suffixIcon}) {
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
      disabledBorder: border,
      suffixIcon: suffixIcon,
    );
  }

  Future<void> _selectService() async {
    FocusScope.of(context).unfocus();
    final service = await showChoiceSheet<ModelService>(
      context,
      title: '选择模型供应商',
      selected: _service,
      choices: [
        for (final service in ModelService.values)
          (value: service, label: service.label),
      ],
    );
    if (!mounted || service == null || service == _service) return;
    _keepDraft();
    if (mounted) setState(() => _loadProfile(service));
  }

  Future<void> _selectModel() async {
    FocusScope.of(context).unfocus();
    final models = await _fetchModels();
    if (!mounted || models == null) return;
    final model = await showChoiceSheet<String>(
      context,
      title: '选择模型',
      selected: _model,
      choices: [
        for (final model in models)
          (value: model, label: modelDisplayName(model)),
      ],
    );
    if (!mounted || model == null || model == _model) return;
    setState(() => _model = model);
  }

  Future<bool> _discardChanges() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => const DeleteConfirmationDialog(
          title: '放弃未保存的修改？',
          description: '所有服务商未保存的修改都将丢失。',
          cancelLabel: '保留编辑',
          confirmLabel: '放弃修改',
        ),
      ) ??
      false;
  String get _apiKey =>
      _key.text.trim().isEmpty ? _saved.apiKey : _key.text.trim();
  Uri? _validatedAddress() {
    if (_apiKey.isEmpty) {
      _notice('请先填写 API 密钥');
      return null;
    }
    final uri = Uri.tryParse(_address.text.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty) {
      _notice('请输入完整的 HTTPS 服务地址，不包含查询参数');
      return null;
    }
    return uri;
  }

  Future<List<String>?> _fetchModels() async {
    final uri = _validatedAddress();
    if (uri == null) return null;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    final catalog = ModelCatalog();
    _catalog = catalog;
    try {
      final models = await catalog.load(baseUrl: uri, apiKey: _apiKey);
      if (!mounted) return null;
      if (models.isEmpty) {
        _notice('服务没有返回模型，已保留当前选择');
        return null;
      }
      return models;
    } on ModelProviderException catch (error) {
      if (mounted) _notice(error.message);
    } on Object catch (error) {
      if (mounted) _notice('无法读取模型列表，请检查服务地址：${errorMessage(error)}');
    } finally {
      catalog.close();
      _catalog = null;
      if (mounted) setState(() => _loading = false);
    }
    return null;
  }

  Future<void> _save() async {
    _keepDraft();
    final selected = _service;
    final configs = <ModelConfig>[];
    for (final service in {
      ..._drafts.keys,
      if (_defaultService != _originalDefault) _defaultService,
    }) {
      _loadProfile(service);
      final uri = _validatedAddress();
      if (uri == null) {
        setState(() {});
        return;
      }
      configs.add(
        ModelConfig(
          service: service,
          apiKey: _apiKey,
          model: _model,
          baseUrl: uri.toString(),
        ),
      );
    }
    _loadProfile(selected);
    final uri = _validatedAddress();
    if (uri == null) return;
    setState(() => _saving = true);
    try {
      await widget.controller.saveConfig(
        ModelConfig(
          service: _service,
          apiKey: _apiKey,
          model: _model,
          baseUrl: uri.toString(),
        ),
        profiles: configs,
        defaultService: _defaultService,
        senderId: widget.accountOnly
            ? null
            : widget.controller.activeConversation.defaultSenderId,
      );
      if (!mounted) return;
      _notice('模型配置已保存');
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, true);
      });
    } on Object catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _notice('保存失败，请稍后重试：${errorMessage(error)}');
      }
    }
  }

  void _notice(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 15,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class _ModelChoice extends StatelessWidget {
  const _ModelChoice({
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  final bool loading;

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: settingsFieldColor(context),
    borderRadius: BorderRadius.circular(26),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color: onTap == null
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (loading)
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    ),
  );
}
