import 'request_adapter_page.dart';
import 'model_context_page.dart';
import 'provider_models_page.dart';
import 'model_provider_icon.dart';
import 'question_icon.dart';
import 'conversation_menu_icon.dart';
import '../../platform/aurai_platform.dart';
import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import 'package:flutter/material.dart';
import '../../domain/model_provider.dart';
import '../../providers/model_context_limits.dart';
import 'chat_controller.dart';
import 'choice_sheet.dart';
import 'delete_confirmation_dialog.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'model_balance_tile.dart';
import 'model_reasoning_field.dart';

part 'model_provider_model_actions.dart';
part 'model_provider_overview.dart';

class ModelProviderDetail extends StatefulWidget {
  const ModelProviderDetail({
    super.key,
    required this.controller,
    required this.service,
    required this.accountOnly,
    this.credentialsOnly = false,
    this.creating = false,
    this.editing = false,
  });
  final ChatController controller;
  final ModelService service;
  final bool accountOnly;
  final bool credentialsOnly;
  final bool creating;
  final bool editing;
  @override
  State<ModelProviderDetail> createState() => _ModelProviderDetailState();
}

class _ModelProviderDetailState extends State<ModelProviderDetail> {
  final _name = TextEditingController();
  final _website = TextEditingController();
  late ProviderProtocol _protocol;
  late List<String> _models;
  late bool _autoSyncModels;
  Future<void> _openRequestAdapters() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RequestAdapterPage(
          controller: widget.controller,
          service: _service,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openModelContext() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ModelContextPage(controller: widget.controller, service: _service),
      ),
    );
    if (mounted) setState(() {});
  }

  ProviderDetails get _details => ProviderDetails(
    requestAdapters: _saved.details?.requestAdapters ?? const {},
    modelContextOverrides: _saved.details?.modelContextOverrides ?? const {},
    name: _name.text.trim(),
    website: _website.text.trim(),
    protocol: _protocol,
    models: _models,
    autoSyncModels: _autoSyncModels,
  );
  ModelConfig get _draft => ModelConfig(
    service: _service,
    apiKey: _apiKey,
    model: _model,
    baseUrl: _address.text.trim(),
    reasoning: _reasoning,
    details: _details,
  );

  final _key = TextEditingController();
  final _address = TextEditingController();
  late ModelService _service;
  late ModelService _originalDefault =
      widget.controller.modelSettings.activeService;
  late ModelService _defaultService = _originalDefault;
  late String _model;
  late ModelReasoning _reasoning;
  late ModelReasoning _initialReasoning;
  late bool _editing = widget.creating || widget.editing;
  var _obscure = true;
  var _saving = false;
  var _allowPop = false;
  var _hasSaved = false;
  ModelConfig get _saved => widget.creating
      ? ModelConfig.defaults(_service)
      : widget.controller.modelSettings.profile(_service);
  bool get _locked => _saving;
  bool get _currentDirty =>
      _name.text != (widget.creating ? '' : _saved.displayName) ||
      _website.text != _saved.website ||
      _protocol != _saved.protocol ||
      _autoSyncModels != _saved.autoSyncModels ||
      _models.join('\n') != _saved.savedModels.join('\n') ||
      _apiKey != _saved.apiKey ||
      _address.text != _saved.baseUrl ||
      _model != _saved.model ||
      _reasoning != _initialReasoning;
  bool get _dirty =>
      _editing && (_currentDirty || _defaultService != _originalDefault);

  @override
  void initState() {
    super.initState();
    final config = widget.controller.config;
    _service = widget.service;
    _key.clear();
    _name.text = widget.creating ? '' : _saved.displayName;
    _website.text = _saved.website;
    _protocol = _saved.protocol;
    _models = [..._saved.savedModels];
    _autoSyncModels = _saved.autoSyncModels;
    _website.addListener(_changed);
    final useConversation = !widget.accountOnly && config.service == _service;
    _model = useConversation ? config.model : _saved.model;
    _reasoning = _saved.reasoning;
    _initialReasoning = _reasoning;
    _address.text = useConversation ? config.baseUrl : _saved.baseUrl;
    _name.addListener(_changed);
    _key.addListener(_changed);
    _address.addListener(_changed);
  }

  void _changed() => setState(() {});
  void _updateModelSelection(bool useAll, List<String> models) => setState(() {
    _autoSyncModels = useAll;
    _models = models;
  });
  @override
  void dispose() {
    _name.dispose();
    _website.dispose();
    _key.dispose();
    _address.dispose();
    super.dispose();
  }

  void _restoreSaved() {
    _name.text = _saved.displayName;
    _website.text = _saved.website;
    _address.text = _saved.baseUrl;
    _key.clear();
    _protocol = _saved.protocol;
    _models = [..._saved.savedModels];
    _autoSyncModels = _saved.autoSyncModels;
    _model = _saved.model;
    _reasoning = _saved.reasoning;
    _initialReasoning = _reasoning;
    _defaultService = _originalDefault;
    _obscure = true;
  }

  Future<void> _back() async {
    if (_locked) return;
    if (_dirty && !await _discardChanges()) return;
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    if (_editing && !widget.creating) {
      setState(() {
        _restoreSaved();
        _editing = false;
      });
      return;
    }
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, _hasSaved);
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || (!_locked && !_editing && !_hasSaved),
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _back();
    },
    child: Scaffold(
      appBar: SettingsAppBar(
        title: widget.creating ? '添加供应商' : '供应商详情',
        onBack: _back,
        leadingAction: _editing
            ? SettingsGlassAction(
                label: '退出编辑',
                icon: Icons.close_rounded,
                iconWidget: const QuestionIcon(type: QuestionIconType.close),
                onPressed: _locked ? null : _back,
              )
            : null,
        actions: [
          SettingsGlassAction(
            label: !_editing
                ? '编辑'
                : _saving
                ? '正在保存'
                : '保存',
            icon: Icons.check_rounded,
            onPressed: _locked || (_editing && !_dirty && !widget.creating)
                ? null
                : _editing
                ? _save
                : () => setState(() => _editing = true),
            iconWidget: !_editing
                ? ConversationMenuIcon(
                    type: ConversationMenuIconType.rename,
                    color: Theme.of(context).colorScheme.onSurface,
                  )
                : _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : SettingsIcon(
                    type: SettingsIconType.check,
                    color: Theme.of(context).colorScheme.onSurface.withValues(
                      alpha:
                          _locked || (_editing && !_dirty && !widget.creating)
                          ? .3
                          : 1,
                    ),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: !_editing
                ? _overview()
                : ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    children: [
                      ...[
                        const _Label('供应商名称'),
                        TextField(
                          controller: _name,
                          enabled: !_locked,
                          maxLength: 60,
                          style: const TextStyle(fontSize: 16),
                          decoration: _fieldDecoration(hint: '例如：我的模型服务'),
                        ),
                        const SizedBox(height: 20),
                      ],
                      const _Label('官网地址'),
                      TextField(
                        controller: _website,
                        enabled: !_locked,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: _fieldDecoration(
                          hint: '选填，例如 https://example.com',
                          suffixIcon: IconButton(
                            tooltip: '打开官网',
                            onPressed: _locked || _website.text.trim().isEmpty
                                ? null
                                : _openWebsite,
                            icon: const SettingsIcon(
                              type: SettingsIconType.chevron,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const _Label('接口协议'),
                      _ModelChoice(
                        label: _protocol.label,
                        onTap: _locked
                            ? null
                            : () async {
                                final value =
                                    await showChoiceSheet<ProviderProtocol>(
                                      context,
                                      title: '接口协议',
                                      selected: _protocol,
                                      choices: [
                                        for (final protocol
                                            in ProviderProtocol.values)
                                          (
                                            value: protocol,
                                            label: protocol.label,
                                          ),
                                      ],
                                    );
                                if (mounted && value != null)
                                  setState(() {
                                    _protocol = value;
                                    _reasoning = ModelReasoning.automatic;
                                  });
                              },
                      ),
                      const SizedBox(height: 24),
                      const _Label('API 密钥'),
                      TextField(
                        controller: _key,
                        enabled: !_locked,
                        obscureText: _obscure,
                        autocorrect: false,
                        enableSuggestions: false,
                        style: const TextStyle(fontSize: 16),
                        decoration: _fieldDecoration(
                          hint:
                              _saved.isConfigured &&
                                  _address.text.trim() == _saved.baseUrl
                              ? '已保存密钥 · 留空保持不变'
                              : '粘贴 API 密钥',
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
                                      : () => setState(
                                          () => _obscure = !_obscure,
                                        ),
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
                        onChanged: (_) => setState(() {}),
                        enabled: !_locked,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        enableSuggestions: false,
                        style: const TextStyle(fontSize: 16),
                        decoration: _fieldDecoration(
                          hint: widget.creating
                              ? 'https://example.com/v1'
                              : _service.defaultBaseUrl,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const _Label('模型'),
                      _ModelChoice(
                        label: _autoSyncModels
                            ? '全部模型'
                            : '已选 ${_models.length} 个模型',
                        onTap: _locked ? null : _openModelManagement,
                      ),
                      ModelReasoningField(
                        service: _service,
                        model: _model,
                        baseUrl: _address.text.trim(),
                        value: _reasoning,
                        providerDefault: true,
                        onChanged: _locked
                            ? null
                            : (value) => setState(() => _reasoning = value),
                      ),
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

  Future<bool> _discardChanges() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => const DeleteConfirmationDialog(
          title: '放弃未保存的修改？',
          description: '当前供应商未保存的修改将丢失。',
          cancelLabel: '保留编辑',
          confirmLabel: '放弃修改',
        ),
      ) ??
      false;
  String get _apiKey => _key.text.trim().isNotEmpty
      ? _key.text.trim()
      : _address.text.trim() == _saved.baseUrl
      ? _saved.apiKey
      : '';
  Uri? _validatedAddress({bool requireKey = true}) {
    if (requireKey && _apiKey.isEmpty) {
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

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _notice('请输入供应商名称');
      return;
    }
    final uri = _validatedAddress(requireKey: false);
    if (uri == null) return;
    setState(() => _saving = true);
    try {
      if (widget.creating) {
        await widget.controller.addModelProvider(
          name: _name.text,
          baseUrl: uri.toString(),
          apiKey: _apiKey,
          website: _details.website,
          protocol: _protocol,
          models: _models,
          autoSyncModels: _autoSyncModels,
          model: _model,
        );
      } else {
        await widget.controller.saveConfig(
          ModelConfig(
            service: _service,
            apiKey: _apiKey,
            model: _model,
            baseUrl: uri.toString(),
            reasoning: _reasoning,
            details: _details,
          ),
          defaultService: widget.credentialsOnly
              ? widget.controller.modelSettings.activeService
              : _defaultService,
          senderId: widget.accountOnly || widget.credentialsOnly
              ? null
              : widget.controller.activeConversation.defaultSenderId,
        );
      }
      if (!mounted) return;
      _notice(widget.credentialsOnly ? '服务商配置已保存' : '模型配置已保存');
      if (widget.creating) {
        setState(() => _allowPop = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context, true);
        });
      } else {
        FocusScope.of(context).unfocus();
        _name.text = _saved.displayName;
        _website.text = _saved.website;
        _address.text = _saved.baseUrl;
        _key.clear();
        setState(() {
          _protocol = _saved.protocol;
          _models = [..._saved.savedModels];
          _autoSyncModels = _saved.autoSyncModels;
          _model = _saved.model;
          _reasoning = _saved.reasoning;
          _initialReasoning = _reasoning;
          _originalDefault = widget.controller.modelSettings.activeService;
          _defaultService = _originalDefault;
          _obscure = true;
          _saving = false;
          _editing = false;
          _hasSaved = true;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _notice('保存失败，请稍后重试：${errorMessage(error)}');
      }
    }
  }

  void _notice(String text) => ScaffoldMessenger.of(context).showGlassSnackBar(
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
  const _ModelChoice({required this.label, required this.onTap});

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
            const SettingsIcon(type: SettingsIconType.chevron),
          ],
        ),
      ),
    ),
  );
}
