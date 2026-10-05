import 'app_bottom_sheet.dart';
import 'app_sheet_surface.dart';
import 'package:flutter/material.dart';
import '../../app/global_ui.dart';
import '../../domain/speech_voice.dart';
import '../../domain/speech_voice_details.dart';
import 'choice_sheet.dart';
import 'question_icon.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class SpeechVoiceFilter {
  const SpeechVoiceFilter({
    this.language = '',
    this.gender = '',
    this.tag = '',
  });
  final String language, gender, tag;
  bool get active => language.isNotEmpty || gender.isNotEmpty || tag.isNotEmpty;
  static bool available(List<SpeechVoice> voices) => voices.any(
    (voice) =>
        voice.details?.tags.isNotEmpty == true ||
        voice.details?.gender?.isNotEmpty == true,
  );

  static bool isLanguage(String tag) =>
      SpeechVoiceDetails.languageNames.values.contains(tag) ||
      tag.endsWith('话') ||
      tag.contains('口音') ||
      tag.contains('方言');

  static String label(String value) => switch (value) {
    'male' => '男声',
    'female' => '女声',
    _ => value,
  };

  static Iterable<String> tagsOf(SpeechVoice voice) =>
      (voice.details?.tags ?? const <String>[]).expand(
        (tag) => tag.split(' · '),
      );

  bool matches(SpeechVoice voice, String query) {
    final details = voice.details;
    final tags = tagsOf(voice).toList();
    if (language.isNotEmpty && !tags.contains(language)) return false;
    if (gender.isNotEmpty && details?.gender != gender) return false;
    if (tag.isNotEmpty && !tags.contains(tag)) return false;
    final text = [
      voice.name,
      voice.id,
      ...tags,
      details?.description ?? '',
      details?.gender ?? '',
      label(details?.gender ?? ''),
    ].join(' ').toLowerCase();
    return query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .every(text.contains);
  }
}

class SpeechVoiceFilterAction extends StatelessWidget {
  const SpeechVoiceFilterAction({
    super.key,
    required this.filter,
    required this.onPressed,
  });
  final SpeechVoiceFilter filter;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SettingsGlassAction(
    label: '筛选音色',
    icon: Icons.filter_list_rounded,
    iconWidget: SettingsIcon(
      type: SettingsIconType.filter,
      color: filter.active
          ? GlobalUI.highlightTextColor(context)
          : Theme.of(context).colorScheme.onSurfaceVariant,
    ),
    onPressed: onPressed,
  );
}

Future<SpeechVoiceFilter?> showSpeechVoiceFilter(
  BuildContext context, {
  required List<SpeechVoice> voices,
  required SpeechVoiceFilter selected,
}) => showAppBottomSheet<SpeechVoiceFilter>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  builder: (_) => _VoiceFilterSheet(voices: voices, selected: selected),
);

class _VoiceFilterSheet extends StatefulWidget {
  const _VoiceFilterSheet({required this.voices, required this.selected});
  final List<SpeechVoice> voices;
  final SpeechVoiceFilter selected;
  @override
  State<_VoiceFilterSheet> createState() => _VoiceFilterSheetState();
}

class _VoiceFilterSheetState extends State<_VoiceFilterSheet> {
  late String _language = widget.selected.language;
  late String _gender = widget.selected.gender;
  late String _tag = widget.selected.tag;

  Future<void> _choose(
    String title,
    String selected,
    List<String> options,
    ValueChanged<String> update,
  ) async {
    final value = await showChoiceSheet<String>(
      context,
      title: title,
      allowSearch: false,
      selected: selected,
      choices: [
        (value: '', label: '不限'),
        for (final option in options)
          (value: option, label: SpeechVoiceFilter.label(option)),
      ],
    );
    if (mounted && value != null) setState(() => update(value));
  }

  Widget _field(
    String title,
    String value,
    List<String> options,
    ValueChanged<String> update,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Material(
          color: settingsFieldColor(context),
          borderRadius: BorderRadius.circular(26),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            title: Text(value.isEmpty ? '不限' : SpeechVoiceFilter.label(value)),
            trailing: const SettingsIcon(type: SettingsIconType.chevronDown),
            onTap: () => _choose(title, value, options, update),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final tags = {
      for (final voice in widget.voices) ...SpeechVoiceFilter.tagsOf(voice),
    };
    final languages = tags.where(SpeechVoiceFilter.isLanguage).toList()..sort();
    final otherTags =
        tags.where((t) => !SpeechVoiceFilter.isLanguage(t)).toList()..sort();
    final genders = {
      for (final voice in widget.voices)
        if (voice.details?.gender case final String gender) gender,
    }.toList()..sort();
    return AppSheetSurface(
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
                        '筛选音色',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SettingsGlassAction(
                      label: '完成',
                      icon: Icons.check_rounded,
                      iconWidget: const SettingsIcon(
                        type: SettingsIconType.check,
                      ),
                      onPressed: () => Navigator.pop(
                        context,
                        SpeechVoiceFilter(
                          language: _language,
                          gender: _gender,
                          tag: _tag,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    children: [
                      if (languages.isNotEmpty)
                        _field(
                          '语言',
                          _language,
                          languages,
                          (v) => _language = v,
                        ),
                      if (genders.isNotEmpty)
                        _field('性别', _gender, genders, (v) => _gender = v),
                      if (otherTags.isNotEmpty)
                        _field('标签', _tag, otherTags, (v) => _tag = v),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
