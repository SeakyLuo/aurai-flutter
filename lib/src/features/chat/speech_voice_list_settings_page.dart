import 'dart:convert';
import 'package:flutter/material.dart';
import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import '../../domain/speech_voice_list_config.dart';
import '../../scheduling/task_unsaved_dialog.dart';
import 'choice_sheet.dart';
import 'provider_api_key_field.dart';
import 'provider_settings_draft.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class SpeechVoiceListSettingsPage extends StatefulWidget {
  const SpeechVoiceListSettingsPage({
    super.key,
    required this.draft,
    this.readOnly = false,
  });
  final ProviderSettingsDraft draft;
  final bool readOnly;
  @override
  State<SpeechVoiceListSettingsPage> createState() =>
      _SpeechVoiceListSettingsPageState();
}

class _SpeechVoiceListSettingsPageState
    extends State<SpeechVoiceListSettingsPage> {
  late final _initial =
      widget.draft.config.speechApi!.voiceList ??
      const SpeechVoiceListConfig(url: '');
  static const _labels = {
    'url': '接口地址',
    'authHeader': '鉴权请求头',
    'authPrefix': '密钥前缀',
    'apiKey': 'API 密钥',
    'accessKey': 'Access Key',
    'secretKey': 'Secret Key',
    'region': '区域',
    'service': '服务',
    'listPath': '列表响应字段',
    'idPath': '接口名称响应字段',
    'namePath': '展示名称响应字段',
    'avatarPath': '头像响应字段',
    'previewTextPath': '默认试听文案响应字段',
    'previewUrlPath': '默认试听音频响应字段',
    'genderPath': '性别响应字段',
    'genderValues': '性别值映射',
    'descriptionPath': '描述响应字段',
    'tagPaths': '详情响应字段',
    'body': '请求参数',
    'headers': '附加请求头',
    'pagePath': '页码请求字段',
    'totalPath': '总数量响应字段',
    'pageSize': '每页数量',
    'maxPages': '最多获取页数',
  };
  late final _fields = {
    for (final key in _labels.keys)
      key: TextEditingController(text: _value(key)),
  };
  late var _auth = _initial.authentication;
  late var _method = _initial.method;
  bool _changed = false, _allowPop = false;
  String _value(String key) {
    if (key == 'avatarPath') return _initial.avatarPath ?? '';
    if (key == 'previewTextPath') return _initial.previewTextPath ?? '';
    if (key == 'previewUrlPath') return _initial.previewUrlPath ?? '';
    if (key == 'genderPath') return _initial.genderPath ?? '';
    if (key == 'descriptionPath') return _initial.descriptionPath ?? '';
    final value = _initial.toJson()[key];
    return value is Map || value is List
        ? const JsonEncoder.withIndent('  ').convert(value)
        : value.toString();
  }

  @override
  void initState() {
    super.initState();
    for (final field in _fields.values) {
      field.addListener(() => setState(() => _changed = true));
    }
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    try {
      final config = SpeechVoiceListConfig.fromJson({
        ..._initial.toJson(),
        for (final entry in _fields.entries) entry.key: entry.value.text,
        'url': _fields['url']!.text.trim(),
        'avatarPath': _fields['avatarPath']!.text.trim().isEmpty
            ? null
            : _fields['avatarPath']!.text.trim(),
        'method': _method,
        'previewTextPath': _fields['previewTextPath']!.text.trim().isEmpty
            ? null
            : _fields['previewTextPath']!.text.trim(),
        'previewUrlPath': _fields['previewUrlPath']!.text.trim().isEmpty
            ? null
            : _fields['previewUrlPath']!.text.trim(),
        'authentication': _auth.name,
        'body': jsonDecode(_fields['body']!.text),
        'genderPath': _fields['genderPath']!.text.trim().isEmpty
            ? null
            : _fields['genderPath']!.text.trim(),
        'descriptionPath': _fields['descriptionPath']!.text.trim().isEmpty
            ? null
            : _fields['descriptionPath']!.text.trim(),
        'genderValues': jsonDecode(_fields['genderValues']!.text),
        'tagPaths': jsonDecode(_fields['tagPaths']!.text),
        'headers': jsonDecode(_fields['headers']!.text),
        'pageSize': int.parse(_fields['pageSize']!.text),
        'maxPages': int.parse(_fields['maxPages']!.text),
      });
      // An empty address explicitly selects the configured local catalog.
      if (config.url.isNotEmpty) config.validate();
      widget.draft.updateDetails({
        'speechApi': {
          ...widget.draft.config.speechApi!.toJson(),
          'voiceList': config.url.isEmpty ? null : config.toJson(),
        },
      });
      setState(() => _allowPop = true);
      Navigator.pop(context);
    } on Object catch (error) {
      ScaffoldMessenger.of(context).showToast(
        SnackBar(content: Text(errorMessage(error))),
        kind: ToastKind.error,
      );
    }
  }

  Future<void> _leave() async {
    final action = await showDialog<String>(
      context: context,
      builder: (_) => const TaskUnsavedDialog(description: '音色列表接口配置还有未保存的修改。'),
    );
    if (!mounted || action == null) return;
    if (action == 'save') {
      await _save();
    } else {
      setState(() => _allowPop = true);
      Navigator.pop(context);
    }
  }

  Future<void> _chooseAuth() async {
    final value = await showChoiceSheet<VoiceListAuthentication>(
      context,
      title: '鉴权方式',
      selected: _auth,
      choices: [
        (value: VoiceListAuthentication.header, label: 'API 密钥'),
        (value: VoiceListAuthentication.hmacSha256, label: 'AK / SK 签名'),
      ],
    );
    if (mounted && value != null)
      setState(() {
        _auth = value;
        _changed = true;
      });
  }

  Future<void> _chooseMethod() async {
    final value = await showChoiceSheet<String>(
      context,
      title: '请求方式',
      selected: _method,
      choices: [(value: 'GET', label: 'GET'), (value: 'POST', label: 'POST')],
    );
    if (mounted && value != null)
      setState(() {
        _method = value;
        _changed = true;
      });
  }

  List<String> get _shown => [
    'url',
    if (_auth == VoiceListAuthentication.header) ...[
      'authHeader',
      'authPrefix',
      'apiKey',
    ] else ...[
      'accessKey',
      'secretKey',
      'region',
      'service',
    ],
    'listPath',
    'idPath',
    'namePath',
    'avatarPath',
    'previewTextPath',
    'previewUrlPath',
    'genderPath',
    'genderValues',
    'descriptionPath',
    'tagPaths',
    'pagePath',
    'totalPath',
    'pageSize',
    'maxPages',
    if (_method == 'POST') 'body',
    'headers',
  ];
  InputDecoration _decoration(String key) => InputDecoration(
    hintText: key == 'url'
        ? '选填，留空使用预设音色列表'
        : key == 'apiKey'
        ? '选填，留空使用语音 API 密钥'
        : key == 'avatarPath'
        ? '选填，不提供头像时留空'
        : _labels[key],
    filled: true,
    fillColor: settingsFieldColor(context),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(26),
      borderSide: BorderSide.none,
    ),
  );
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
  Widget _choice(String title, String value, VoidCallback action) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _label(title),
      Material(
        color: settingsFieldColor(context),
        borderRadius: BorderRadius.circular(26),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          title: Text(value),
          trailing: const SettingsIcon(type: SettingsIconType.chevron),
          onTap: action,
        ),
      ),
      const SizedBox(height: 24),
    ],
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || !_changed,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        title: '音色列表接口配置',
        onBack: () => Navigator.maybePop(context),
        actions: [
          if (!widget.readOnly)
            SettingsGlassAction(
              label: '保存',
              icon: Icons.check_rounded,
              iconWidget: const SettingsIcon(type: SettingsIconType.check),
              onPressed: _save,
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
                widget.readOnly
                    ? const EdgeInsets.fromLTRB(12, 12, 12, 32)
                    : const EdgeInsets.fromLTRB(16, 20, 16, 32),
              ),
              children: widget.readOnly
                  ? [
                      for (final key in _shown)
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          title: Text(_labels[key]!),
                          subtitle: Text(
                            ['apiKey', 'secretKey', 'accessKey'].contains(key)
                                ? _fields[key]!.text.isEmpty
                                      ? '未设置'
                                      : '已配置'
                                : _fields[key]!.text.isEmpty
                                ? '未设置'
                                : _fields[key]!.text,
                          ),
                        ),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        title: const Text('鉴权方式'),
                        subtitle: Text(
                          _auth == VoiceListAuthentication.header
                              ? 'API 密钥'
                              : 'AK / SK 签名',
                        ),
                      ),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        title: const Text('请求方式'),
                        subtitle: Text(_method),
                      ),
                    ]
                  : [
                      _choice('请求方式', _method, _chooseMethod),
                      _choice(
                        '鉴权方式',
                        _auth == VoiceListAuthentication.header
                            ? 'API 密钥'
                            : 'AK / SK 签名',
                        _chooseAuth,
                      ),
                      for (final key in _shown) ...[
                        _label(_labels[key]!),
                        if (['apiKey', 'secretKey', 'accessKey'].contains(key))
                          ProviderApiKeyField(
                            controller: _fields[key]!,
                            enabled: true,
                            decoration: _decoration(key),
                          )
                        else
                          TextField(
                            controller: _fields[key],
                            autocorrect: false,
                            enableSuggestions: false,
                            minLines:
                                [
                                  'body',
                                  'headers',
                                  'genderValues',
                                  'tagPaths',
                                ].contains(key)
                                ? 3
                                : 1,
                            maxLines:
                                [
                                  'body',
                                  'headers',
                                  'genderValues',
                                  'tagPaths',
                                ].contains(key)
                                ? 8
                                : 1,
                            decoration: _decoration(key),
                          ),
                        const SizedBox(height: 24),
                      ],
                    ],
            ),
          ),
        ),
      ),
    ),
  );
}
