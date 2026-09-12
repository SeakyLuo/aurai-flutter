import 'package:flutter/material.dart';
import '../../utils/widget_utils.dart';
import '../../domain/model_provider.dart';
import '../../providers/model_catalog.dart';
import 'chat_controller.dart';
import 'choice_sheet.dart';

class ModelSettingsSheet extends StatefulWidget {
  const ModelSettingsSheet({
    super.key,
    required this.controller,
    required this.continueAfterSave,
  });
  final ChatController controller;
  final bool continueAfterSave;
  static Future<bool> show(
    BuildContext context, {
    required ChatController controller,
    required bool continueAfterSave,
  }) async {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..removeCurrentSnackBar();
    return await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => ModelSettingsSheet(
              controller: controller,
              continueAfterSave: continueAfterSave,
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
  late ModelService _service;
  late String _model;
  var _models = <String>[];
  var _obscure = true;
  var _saving = false;
  var _loading = false;
  var _allowPop = false;
  ModelCatalog? _catalog;
  ModelConfig get _saved => widget.controller.modelSettings.profile(_service);
  bool get _locked => _saving || _loading;
  bool get _dirty =>
      _key.text.isNotEmpty ||
      _address.text != _saved.baseUrl ||
      _model != _saved.model;
  @override
  void initState() {
    super.initState();
    _loadProfile(widget.controller.modelSettings.activeService);
    _key.addListener(_changed);
    _address.addListener(_changed);
  }

  void _changed() => setState(() {});
  void _loadProfile(ModelService service) {
    _service = service;
    _key.clear();
    _address.text = _saved.baseUrl;
    _model = _saved.model;
    _models = {_saved.model, service.defaultModel}.toList();
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
      appBar: AppBar(
        title: const Text('模型设置'),
        leading: IconButton(
          onPressed: _locked ? null : () => Navigator.maybePop(context),
          tooltip: '返回',
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  children: [
                    const _Label('模型服务'),
                    ChoiceField(
                      label: _service.label,
                      onTap: _locked ? null : _selectService,
                    ),
                    const SizedBox(height: 24),
                    const _Label('API 密钥'),
                    TextField(
                      controller: _key,
                      enabled: !_locked,
                      obscureText: _obscure,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        hintText: _saved.isConfigured
                            ? '已保存密钥 · 留空保持不变'
                            : '粘贴服务提供的 API 密钥',
                        suffixIcon: IconButton(
                          onPressed: _locked
                              ? null
                              : () => setState(() => _obscure = !_obscure),
                          tooltip: _obscure ? '显示密钥' : '隐藏密钥',
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _Label('服务地址'),
                    TextField(
                      controller: _address,
                      enabled: !_locked,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        hintText: _service.defaultBaseUrl,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _Label('使用的模型'),
                    ChoiceField(
                      label: modelDisplayName(_model),
                      onTap: _locked ? null : _selectModel,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _locked ? null : _fetchModels,
                        icon: _loading
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.cloud_download_outlined,
                                size: 18,
                              ),
                        label: Text(_loading ? '正在获取模型…' : '从服务获取模型'),
                      ),
                    ),
                    Text(
                      '列表由当前服务提供。请选择支持对话和工具调用的模型。',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  child: WidgetUtils.primaryButton(
                    width: double.infinity,
                    onPressed: _locked ? null : _save,
                    text: _saving
                        ? '正在保存…'
                        : widget.continueAfterSave
                        ? '保存并继续任务'
                        : '保存并使用',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Future<void> _selectService() async {
    FocusScope.of(context).unfocus();
    final service = await showChoiceSheet<ModelService>(
      context,
      title: '选择模型服务',
      selected: _service,
      choices: [
        for (final service in ModelService.values)
          (value: service, label: service.label),
      ],
    );
    if (!mounted || service == null || service == _service) return;
    if (_dirty && !await _discardChanges()) return;
    if (mounted) setState(() => _loadProfile(service));
  }

  Future<void> _selectModel() async {
    FocusScope.of(context).unfocus();
    final model = await showChoiceSheet<String>(
      context,
      title: '选择模型',
      selected: _model,
      choices: [
        for (final model in _models)
          (value: model, label: modelDisplayName(model)),
      ],
    );
    if (!mounted || model == null || model == _model) return;
    setState(() => _model = model);
  }

  Future<bool> _discardChanges() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('放弃未保存的修改？'),
          content: const Text('当前服务的修改尚未保存。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('保留编辑'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('放弃修改'),
            ),
          ],
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

  Future<void> _fetchModels() async {
    final uri = _validatedAddress();
    if (uri == null) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    final catalog = ModelCatalog();
    _catalog = catalog;
    try {
      final models = await catalog.load(baseUrl: uri, apiKey: _apiKey);
      if (!mounted) return;
      setState(() => _models = {_model, ...models}.toList());
      _notice(models.isEmpty ? '服务没有返回模型，已保留当前选择' : '已获取模型，请选择要使用的模型');
    } on ModelProviderException catch (error) {
      if (mounted) _notice(error.message);
    } on Object {
      if (mounted) _notice('无法读取模型列表，请检查服务地址');
    } finally {
      catalog.close();
      _catalog = null;
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
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
      );
      if (!mounted) return;
      _notice('模型配置已保存');
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, true);
      });
    } on Object {
      if (mounted) {
        setState(() => _saving = false);
        _notice('保存失败，请稍后重试');
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
        88 + MediaQuery.paddingOf(context).bottom,
      ),
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
  );
}
