import 'package:flutter/material.dart';
import '../../app/glass_notice.dart';
import '../../app/ui_action.dart';
import '../../domain/error_message.dart';
import '../../domain/ai_profile.dart';
import '../../domain/ai_speech_selection.dart';
import '../../domain/model_provider.dart';
import '../../domain/profile_gender.dart';
import '../../providers/model_purpose_catalog.dart';
import 'speech_voice_pages.dart';
import '../../domain/speech_voice.dart';
import '../../scheduling/task_unsaved_dialog.dart';
import 'chat_controller.dart';
import 'model_choice_sheet.dart';
import 'model_settings_sheet.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'voice_choice_sheet.dart';
import 'provider_settings_draft.dart';

class AiSpeechPage extends StatefulWidget {
  const AiSpeechPage({
    super.key,
    required this.controller,
    required this.profile,
  });
  final ChatController controller;
  final AiProfile profile;
  @override
  State<AiSpeechPage> createState() => _AiSpeechPageState();
}

class _AiSpeechPageState extends State<AiSpeechPage> {
  late ModelService? _service =
      widget.profile.preferences.speech?.service ??
      widget
          .controller
          .modelSettings
          .modelDefaults[ModelPurpose.speechSynthesis]
          ?.service;
  late String _model =
      widget.profile.preferences.speech?.model ??
      widget
          .controller
          .modelSettings
          .modelDefaults[ModelPurpose.speechSynthesis]
          ?.model ??
      '';
  late String _voice = widget.profile.preferences.speech?.voice ?? '';
  List<SpeechVoice> _loadedVoices = const [];
  bool _changed = false, _saving = false, _allowPop = false;
  late final _previewText = TextEditingController(
    text: '你好，我是${widget.profile.sender.name}，这是我的声音。',
  );

  @override
  void dispose() {
    _previewText.dispose();
    super.dispose();
  }

  ModelConfig? get _account => _service == null
      ? null
      : widget.controller.modelSettings.profile(_service!);
  String get _voiceName {
    for (final voice in [...?_account?.speechApi?.voices, ..._loadedVoices]) {
      if (voice.id == _voice) return voice.name;
    }
    return '选择音色';
  }

  Future<void> _provider() async {
    final selected = await showProviderChoiceSheet(
      context,
      profiles: widget.controller.modelSettings.profiles,
      title: '供应商',
      selected: _service,
      choices: [
        for (final account in widget.controller.modelSettings.profiles.values)
          if (account.supportedModelPurposes.contains(
            ModelPurpose.speechSynthesis,
          ))
            (value: account.service, label: account.displayName),
      ],
    );
    if (!mounted ||
        selected == null ||
        (selected == _service && _model.isNotEmpty))
      return;
    final models = _speechModels(
      widget.controller.modelSettings.profile(selected),
    );
    setState(() {
      _service = selected;
      _model = models.firstOrNull ?? '';
      _voice = '';
      _loadedVoices = const [];
      _changed = true;
    });
  }

  Future<bool> _configured() async {
    if (_account == null) {
      await _provider();
    }
    if (!mounted || _account == null) return false;
    if (!_account!.supportedModelPurposes.contains(
      ModelPurpose.speechSynthesis,
    )) {
      _notice('该供应商不提供语音合成，请重新选择供应商');
      return false;
    }
    if (!_account!.isSpeechConfigured || _account!.speechApi == null) {
      await ModelSettingsSheet.show(
        context,
        controller: widget.controller,
        accountOnly: true,
        continueAfterSave: false,
        initialService: _service,
      );
      if (!mounted) return false;
      setState(() {});
    }
    return _account!.isSpeechConfigured && _account!.speechApi != null;
  }

  List<String> _speechModels(ModelConfig account) =>
      {
            ...account.modelCatalog.map((model) => model.id),
            ...account.savedModels,
            ...?account.details?.modelPurposes.keys,
          }
          .where(
            (model) =>
                modelPurposesFor(
                  account,
                  model,
                ).contains(ModelPurpose.speechSynthesis) &&
                (account.autoSyncModels || account.savedModels.contains(model)),
          )
          .toList();

  Future<void> _selectModel() async {
    if (!await _configured() || !mounted) return;
    final account = _account!;
    final models = _speechModels(account);
    if (models.isEmpty) {
      _notice('请在供应商的模型管理中添加可用模型');
      return;
    }
    final selected = await showModelOptionsSheet(
      context,
      title: '语音合成模型',
      selected: _model,
      choices: [
        for (final model in models)
          (value: model, label: account.displayModel(model)),
      ],
    );
    if (mounted && selected != null)
      setState(() {
        _model = selected;
        _changed = true;
      });
  }

  Future<void> _selectVoice() async {
    if (!await _configured() || !mounted) return;
    final gender = widget.profile.preferences.gender;
    final account = _account!;
    if (!account.speechApi!.autoSyncVoices &&
        account.speechApi!.voices.isEmpty) {
      _notice('请在供应商的音色管理中添加可用音色');
      return;
    }
    List<SpeechVoice> ordered(List<SpeechVoice> voices) =>
        gender == ProfileGender.unknown
        ? voices
        : [
            ...voices.where((voice) => voice.details?.gender == gender.name),
            ...voices.where((voice) => voice.details?.gender != gender.name),
          ];
    final pages = account.speechApi!.autoSyncVoices
        ? SpeechVoicePages(account)
        : null;
    final selected = await showVoiceChoiceSheet(
      context,
      account: _account!.copyWith(model: _model),
      voices: ordered(pages?.voices ?? account.speechApi!.voices),
      hasMore: pages == null ? null : () => pages.hasMore,
      loadVoices: pages == null
          ? null
          : () async {
              await pages.loadNext();
              if (mounted) setState(() => _loadedVoices = pages.voices);
              return ordered(pages.voices);
            },
      selected: _voice,
      text: _previewText.text,
      onTextChanged: (text) => _previewText.text = text,
      onRename: (voice) async {
        final saved = await _renameVoice(voice);
        if (saved && pages != null) pages.names[voice.id] = voice.name;
        return saved;
      },
    );
    pages?.dispose();
    if (mounted && selected != null)
      setState(() {
        _voice = selected;
        _changed = true;
      });
  }

  AiSpeechSelection get _selection =>
      AiSpeechSelection(service: _service!, model: _model, voice: _voice);

  Future<bool> _renameVoice(SpeechVoice updated) async {
    final saved = await runUiAction(context, () async {
      final account = _account!;
      final speech = account.speechApi!;
      final draft = ProviderSettingsDraft(account);
      draft.updateDetails({
        'speechApi': {
          ...speech.toJson(),
          'voices': [
            for (final voice in speech.voices)
              (voice.id == updated.id ? updated : voice).toJson(),
          ],
          'voiceCatalog': {
            for (final voice in speech.voiceCatalog) voice.id: voice,
            updated.id: updated,
          }.values.map((voice) => voice.toJson()).toList(),
        },
      });
      await saveProviderEditorConfig(
        widget.controller,
        null,
        draft.config,
        defaultService: widget.controller.modelSettings.activeService,
      );
    });
    if (mounted && saved)
      setState(() {
        _loadedVoices = [
          for (final voice in _loadedVoices)
            voice.id == updated.id ? updated : voice,
        ];
      });
    return saved;
  }

  Future<void> _save() async {
    if (_model.isEmpty || _voice.isEmpty) {
      _notice('请选择语音模型和音色', kind: ToastKind.warning);
      return;
    }
    if (!await _configured() || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.controller.saveAi(
        widget.profile.copyWith(
          preferences: widget.profile.preferences.copyWith(speech: _selection),
        ),
      );
      if (mounted) {
        setState(() => _allowPop = true);
        Navigator.pop(context);
      }
    } on Object catch (error) {
      if (mounted) _notice(errorMessage(error), kind: ToastKind.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _leave() async {
    final action = await showDialog<String>(
      context: context,
      builder: (_) => const TaskUnsavedDialog(description: '声音设置还有未保存的修改。'),
    );
    if (!mounted || action == null) return;
    if (action == 'save') {
      await _save();
    } else {
      setState(() => _allowPop = true);
      Navigator.pop(context);
    }
  }

  void _notice(String message, {ToastKind kind = ToastKind.info}) =>
      ScaffoldMessenger.of(
        context,
      ).showToast(SnackBar(content: Text(message)), kind: kind);

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || (!_changed && !_saving),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && !_saving) _leave();
    },
    child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        title: '声音',
        onBack: () => Navigator.maybePop(context),
        actions: [
          SettingsGlassAction(
            label: '保存',
            icon: Icons.check_rounded,
            iconWidget: const SettingsIcon(type: SettingsIconType.check),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: SettingsPageBody(
        child: ListView(
          padding: settingsPagePadding(
            context,
            const EdgeInsets.fromLTRB(16, 12, 16, 16),
          ),
          children: [
            _label('供应商', first: true),
            _choice(_account?.displayName ?? '选择供应商', _provider),
            _label('语音合成模型'),
            _choice(
              _model.isEmpty ? '选择模型' : _account!.displayModel(_model),
              _selectModel,
            ),
            _label('音色'),
            _choice(_voiceName, _selectVoice),
          ],
        ),
      ),
    ),
  );

  Widget _label(String title, {bool first = false}) => Padding(
    padding: EdgeInsets.fromLTRB(18, first ? 0 : 16, 18, 12),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 15,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
  Widget _choice(String value, VoidCallback? action) => Material(
    color: settingsFieldColor(context),
    borderRadius: BorderRadius.circular(26),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      minTileHeight: settingsCardHeight,
      contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 12),
      title: Text(value, style: const TextStyle(fontSize: 15)),
      trailing: const SettingsIcon(type: SettingsIconType.chevronDown),
      onTap: _saving ? null : action,
    ),
  );
}
