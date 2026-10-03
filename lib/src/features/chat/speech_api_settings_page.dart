import 'dart:convert';
import 'package:flutter/material.dart';
import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import '../../domain/speech_api_config.dart';
import '../../scheduling/task_unsaved_dialog.dart';
import 'choice_sheet.dart';
import 'provider_settings_draft.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'provider_api_key_field.dart';
import 'provider_voice_management_page.dart';
import 'chat_controller.dart';

/// Uses the same draft/save lifecycle as the other supplier settings editors.
class SpeechApiSettingsPage extends StatefulWidget {
  const SpeechApiSettingsPage({
    super.key,
    required this.draft,
    required this.controller,
    this.readOnly = false,
  });
  final ProviderSettingsDraft draft;
  final ChatController controller;
  final bool readOnly;
  @override
  State<SpeechApiSettingsPage> createState() => _SpeechApiSettingsPageState();
}

class _SpeechApiSettingsPageState extends State<SpeechApiSettingsPage> {
  static const _empty = SpeechApiConfig(
    path: '',
    authHeader: 'Authorization',
    authPrefix: 'Bearer ',
    modelPath: 'model',
    textPath: 'input.text',
    voicePath: 'input.voice',
    audioPath: 'output.audio.url',
    audioEncoding: SpeechAudioEncoding.url,
    fileExtension: 'wav',
  );
  late final _initial = widget.draft.config.speechApi ?? _empty;
  static const _labels = {
    'baseUrl': '语音服务地址',
    'path': '接口路径',
    'authHeader': '鉴权请求头',
    'authPrefix': '密钥前缀',
    'modelPath': '模型请求字段',
    'modelHeader': '模型请求头',
    'textPath': '文字请求字段',
    'voicePath': '音色请求字段',
    'audioPath': '音频响应字段',
    'fileExtension': '音频文件格式',
    'maxCharacters': '每段文字长度',
    'codePath': '状态响应字段',
    'successCodes': '成功状态',
    'completionCode': '完成状态',
    'body': '附加请求参数',
    'headers': '附加请求头',
  };
  late final _fields = {
    for (final key in _labels.keys)
      key: TextEditingController(text: _value(key)),
  };
  late SpeechResponseFormat _response = _initial.responseFormat;
  late SpeechAudioEncoding _encoding = _initial.audioEncoding;
  late final _voiceDraft = ProviderSettingsDraft(widget.draft.config)
    ..updateDetails({'speechApi': _initial.toJson()});
  late final _key = TextEditingController(
    text: widget.draft.config.details?.speechApiKey ?? '',
  );
  bool _changed = false, _allowPop = false;
  String _value(String key) {
    final value = _initial.toJson()[key];
    return value is Map || value is List
        ? const JsonEncoder.withIndent('  ').convert(value)
        : value?.toString() ?? '';
  }

  void _changedValue() => setState(() => _changed = true);
  @override
  void initState() {
    super.initState();
    _key.addListener(_changedValue);
  }

  @override
  void dispose() {
    for (final field in [..._fields.values, _key]) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    try {
      final api = SpeechApiConfig.fromJson({
        ..._voiceDraft.config.speechApi!.toJson(),
        for (final entry in _fields.entries) entry.key: entry.value.text,
        'responseFormat': _response.name,
        'audioEncoding': _encoding.name,
        'maxCharacters': int.parse(_fields['maxCharacters']!.text),
        'body': jsonDecode(_fields['body']!.text),
        'headers': jsonDecode(_fields['headers']!.text),
        'successCodes': jsonDecode(_fields['successCodes']!.text),
        'completionCode': _fields['completionCode']!.text.isEmpty
            ? null
            : jsonDecode(_fields['completionCode']!.text),
      });
      api.validate();
      widget.draft.updateDetails({
        'speechApi': api.toJson(),
        'speechApiKey': _key.text.trim(),
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
      builder: (_) => const TaskUnsavedDialog(description: '语音接口配置还有未保存的修改。'),
    );
    if (!mounted || action == null) return;
    if (action == 'save') {
      await _save();
    } else {
      setState(() => _allowPop = true);
      Navigator.pop(context);
    }
  }

  InputDecoration _decoration(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: settingsFieldColor(context),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(26),
      borderSide: BorderSide.none,
    ),
  );
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
  Widget _field(
    String label,
    TextEditingController field, {
    bool multiline = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 24),
      _label(label),
      TextField(
        controller: field,
        autocorrect: false,
        enableSuggestions: false,
        minLines: multiline ? 3 : 1,
        maxLines: multiline ? 8 : 1,
        onChanged: (_) => _changedValue(),
        decoration: _decoration(label),
      ),
    ],
  );
  Widget _choice(String text, VoidCallback onTap, {bool sheet = false}) =>
      Material(
        color: settingsFieldColor(context),
        borderRadius: BorderRadius.circular(26),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          minTileHeight: settingsCardHeight,
          contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 12),
          title: Text(text),
          trailing: SettingsIcon(
            type: sheet
                ? SettingsIconType.chevronDown
                : SettingsIconType.chevron,
          ),
          onTap: onTap,
        ),
      );
  String get _voiceSummary => _voiceDraft.config.speechApi!.autoSyncVoices
      ? '默认全部'
      : '已选 ${_voiceDraft.config.speechApi!.voices.length} 个音色';

  Future<void> _voiceManagement() async {
    if (!widget.readOnly) {
      _voiceDraft.updateDetails({'speechApiKey': _key.text.trim()});
    }
    final before = jsonEncode(_voiceDraft.config.speechApi!.toJson());
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderVoiceManagementPage(
          controller: widget.controller,
          draft: _voiceDraft,
          readOnly: widget.readOnly,
        ),
      ),
    );
    if (!mounted) return;
    if (widget.readOnly) {
      setState(
        () => _voiceDraft.config = widget.controller.modelSettings.profile(
          widget.draft.config.service,
        ),
      );
    } else if (before != jsonEncode(_voiceDraft.config.speechApi!.toJson())) {
      _changedValue();
    }
  }

  List<Widget> _overview() {
    if (widget.draft.config.speechApi == null)
      return [
        const ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 8),
          title: Text('语音接口配置'),
          subtitle: Text('未设置'),
        ),
      ];
    return [
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('音色管理'),
        subtitle: Text(_voiceSummary),
        trailing: const SettingsIcon(type: SettingsIconType.chevron),
        onTap: _voiceManagement,
      ),
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        title: const Text('语音 API 密钥'),
        subtitle: Text(_key.text.isEmpty ? '使用供应商 API 密钥' : '已配置'),
      ),
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        title: const Text('响应格式'),
        subtitle: Text(
          _response == SpeechResponseFormat.json ? 'JSON' : '逐行 JSON',
        ),
      ),
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        title: const Text('音频返回方式'),
        subtitle: Text(
          _encoding == SpeechAudioEncoding.url ? '音频地址' : 'Base64 音频',
        ),
      ),
      for (final key in _labels.keys)
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          title: Text(_labels[key]!),
          subtitle: Text(_value(key).isEmpty ? '未设置' : _value(key)),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || !_changed,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        title: '语音接口配置',
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
                  ? _overview()
                  : [
                      _label('音色管理'),
                      _choice(_voiceSummary, _voiceManagement),
                      const SizedBox(height: 24),
                      _label('语音 API 密钥'),
                      ProviderApiKeyField(
                        controller: _key,
                        enabled: true,
                        decoration: _decoration('选填，留空使用供应商 API 密钥'),
                      ),
                      const SizedBox(height: 24),
                      _label('响应格式'),
                      _choice(
                        _response == SpeechResponseFormat.json
                            ? 'JSON'
                            : '逐行 JSON',
                        () async {
                          final value =
                              await showChoiceSheet<SpeechResponseFormat>(
                                context,
                                title: '响应格式',
                                selected: _response,
                                choices: [
                                  (
                                    value: SpeechResponseFormat.json,
                                    label: 'JSON',
                                  ),
                                  (
                                    value: SpeechResponseFormat.jsonLines,
                                    label: '逐行 JSON',
                                  ),
                                ],
                              );
                          if (mounted && value != null)
                            setState(() {
                              _response = value;
                              _changed = true;
                            });
                        },
                        sheet: true,
                      ),
                      const SizedBox(height: 24),
                      _label('音频返回方式'),
                      _choice(
                        _encoding == SpeechAudioEncoding.url
                            ? '音频地址'
                            : 'Base64 音频',
                        () async {
                          final value =
                              await showChoiceSheet<SpeechAudioEncoding>(
                                context,
                                title: '音频返回方式',
                                selected: _encoding,
                                choices: [
                                  (
                                    value: SpeechAudioEncoding.url,
                                    label: '音频地址',
                                  ),
                                  (
                                    value: SpeechAudioEncoding.base64,
                                    label: 'Base64 音频',
                                  ),
                                ],
                              );
                          if (mounted && value != null)
                            setState(() {
                              _encoding = value;
                              _changed = true;
                            });
                        },
                        sheet: true,
                      ),
                      for (final entry in _fields.entries)
                        _field(
                          _labels[entry.key]!,
                          entry.value,
                          multiline:
                              entry.key == 'body' || entry.key == 'headers',
                        ),
                    ],
            ),
          ),
        ),
      ),
    ),
  );
}
