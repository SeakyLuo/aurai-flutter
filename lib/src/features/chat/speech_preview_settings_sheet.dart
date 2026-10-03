import 'package:flutter/material.dart';
import '../../app/global_ui.dart';
import '../../domain/speech_preview_mode.dart';
import 'choice_sheet.dart';
import 'model_choice_sheet.dart';
import 'question_icon.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

typedef SpeechPreviewSettings = ({
  String model,
  String text,
  SpeechPreviewMode mode,
});

Future<SpeechPreviewSettings?> showSpeechPreviewSettingsSheet(
  BuildContext context, {
  required String text,
  required SpeechPreviewMode mode,
  required bool hasDefaultText,
  required bool hasDefaultAudio,
  String model = '',
  List<({String id, String name})>? models,
}) => showModalBottomSheet<SpeechPreviewSettings>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  builder: (_) => _SpeechPreviewSettingsSheet(
    text: text,
    model: model,
    models: models,
    mode: mode,
    hasDefaultText: hasDefaultText,
    hasDefaultAudio: hasDefaultAudio,
  ),
);

class _SpeechPreviewSettingsSheet extends StatefulWidget {
  const _SpeechPreviewSettingsSheet({
    required this.text,
    required this.model,
    required this.models,
    required this.mode,
    required this.hasDefaultText,
    required this.hasDefaultAudio,
  });
  final String text, model;
  final List<({String id, String name})>? models;
  final SpeechPreviewMode mode;
  final bool hasDefaultText, hasDefaultAudio;
  @override
  State<_SpeechPreviewSettingsSheet> createState() =>
      _SpeechPreviewSettingsSheetState();
}

class _SpeechPreviewSettingsSheetState
    extends State<_SpeechPreviewSettingsSheet> {
  late final _text = TextEditingController(text: widget.text);
  late String _model = widget.model;
  late SpeechPreviewMode _mode = widget.mode;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _selectModel() async {
    final model = await showModelOptionsSheet(
      context,
      title: '语音合成模型',
      selected: _model,
      choices: [
        for (final entry in widget.models!)
          (value: entry.id, label: entry.name),
      ],
    );
    if (mounted && model != null) setState(() => _model = model);
  }

  Future<void> _selectMode() async {
    final mode = await showChoiceSheet<SpeechPreviewMode>(
      context,
      title: '试听方式',
      selected: _mode,
      choices: [
        for (final mode in SpeechPreviewMode.values)
          if (mode == SpeechPreviewMode.customText &&
                  !widget.hasDefaultText &&
                  !widget.hasDefaultAudio ||
              mode == SpeechPreviewMode.providerText &&
                  widget.hasDefaultText &&
                  (widget.models == null || widget.models!.isNotEmpty) ||
              mode == SpeechPreviewMode.providerAudio && widget.hasDefaultAudio)
            (value: mode, label: mode.label),
      ],
    );
    if (mounted && mode != null) setState(() => _mode = mode);
  }

  String get _modelName {
    for (final entry in widget.models!) {
      if (entry.id == _model) return entry.name;
    }
    return '选择语音模型';
  }

  bool get _canSave =>
      (_mode != SpeechPreviewMode.customText || _text.text.trim().isNotEmpty) &&
      (_mode == SpeechPreviewMode.providerAudio ||
          widget.models == null ||
          _model.isNotEmpty);

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
  Widget _choice(String label, VoidCallback onTap) => Material(
    color: settingsFieldColor(context),
    borderRadius: BorderRadius.circular(26),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      title: Text(label),
      trailing: const SettingsIcon(type: SettingsIconType.chevronDown),
      onTap: onTap,
    ),
  );

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: GlobalUI.bottomSheetBorderRadius,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    SettingsGlassAction(
                      label: '关闭',
                      icon: Icons.close_rounded,
                      iconWidget: const QuestionIcon(
                        type: QuestionIconType.close,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        '试听设置',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SettingsGlassAction(
                      label: '保存',
                      icon: Icons.check_rounded,
                      iconWidget: const SettingsIcon(
                        type: SettingsIconType.check,
                      ),
                      onPressed: _canSave
                          ? () => Navigator.pop(context, (
                              model: _model,
                              text: _text.text,
                              mode: _mode,
                            ))
                          : null,
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _label('试听方式'),
                      _choice(_mode.label, _selectMode),
                      if (_mode != SpeechPreviewMode.providerAudio &&
                          widget.models != null) ...[
                        const SizedBox(height: 20),
                        _label('语音合成模型'),
                        _choice(_modelName, _selectModel),
                      ],
                      const SizedBox(height: 20),
                      if (_mode == SpeechPreviewMode.customText) ...[
                        _label('试听文案'),
                        TextField(
                          controller: _text,
                          minLines: 3,
                          maxLines: 6,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: '输入想试听的话',
                            filled: true,
                            fillColor: settingsFieldColor(context),
                            contentPadding: const EdgeInsets.all(18),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(26),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ] else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            _mode == SpeechPreviewMode.providerAudio
                                ? '播放供应商为每个音色提供的试听音频。'
                                : '使用供应商为每个音色提供的默认文案生成语音。',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
