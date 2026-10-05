import 'app_bottom_sheet.dart';
import 'app_sheet_surface.dart';
import 'app_sheet_body.dart';
import 'package:flutter/material.dart';
import '../../domain/speech_voice.dart';

import '../../domain/model_provider.dart';
import '../../widgets/empty_data_view.dart';
import 'question_icon.dart';
import 'settings_appearance.dart';
import 'speech_preview_button.dart';
import 'speech_voice_row.dart';
import '../../domain/speech_preview_mode.dart';
import 'floating_search_layout.dart';
import 'speech_voice_filter.dart';
import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import 'speech_voice_list_skeleton.dart';
import 'pagination_listener.dart';

Future<String?> showVoiceChoiceSheet(
  BuildContext context, {
  required ModelConfig account,
  required List<SpeechVoice> voices,
  required String selected,
  required String text,
  required ValueChanged<String> onTextChanged,
  required Future<bool> Function(SpeechVoice) onRename,
  Future<List<SpeechVoice>> Function()? loadVoices,
  bool Function()? hasMore,
}) => showAppBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  builder: (_) => _VoiceChoiceSheet(
    account: account,
    voices: voices,
    selected: selected,
    text: text,
    onTextChanged: onTextChanged,
    onRename: onRename,
    loadVoices: loadVoices,
    hasMore: hasMore,
  ),
);

class _VoiceChoiceSheet extends StatefulWidget {
  const _VoiceChoiceSheet({
    required this.account,
    required this.voices,
    required this.selected,
    required this.text,
    required this.onTextChanged,
    required this.onRename,
    this.loadVoices,
    this.hasMore,
  });
  final ModelConfig account;
  final List<SpeechVoice> voices;
  final String selected, text;
  final ValueChanged<String> onTextChanged;
  final Future<bool> Function(SpeechVoice) onRename;
  final Future<List<SpeechVoice>> Function()? loadVoices;
  final bool Function()? hasMore;

  @override
  State<_VoiceChoiceSheet> createState() => _VoiceChoiceSheetState();
}

class _VoiceChoiceSheetState extends State<_VoiceChoiceSheet> {
  String get _text => widget.text;
  SpeechPreviewMode _defaultMode(List<SpeechVoice> voices) =>
      voices.any((voice) => voice.previewUrl?.isNotEmpty == true)
      ? SpeechPreviewMode.providerAudio
      : voices.any((voice) => voice.previewText?.isNotEmpty == true)
      ? SpeechPreviewMode.providerText
      : SpeechPreviewMode.customText;
  late SpeechPreviewMode _mode = _defaultMode(_voices);
  late bool _loading = widget.loadVoices != null && widget.voices.isEmpty;
  String? _previewVoice;
  late List<SpeechVoice> _voices = widget.voices;

  @override
  void initState() {
    super.initState();
    if (widget.loadVoices != null) _loadVoices();
  }

  final _renamed = <String, String>{};

  Future<void> _nextPage() async {
    final voices = await widget.loadVoices!();
    if (!mounted) return;
    setState(() {
      _voices = voices.map((v) => v.renamed(_renamed[v.id] ?? v.name)).toList();
    });
  }

  Future<void> _loadVoices() async {
    try {
      final voices = await widget.loadVoices!();
      if (!mounted) return;
      setState(() {
        _voices = voices;
        _mode = _defaultMode(voices);
      });
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showToast(
          SnackBar(content: Text(errorMessage(error))),
          kind: ToastKind.error,
        );
        if (_voices.isEmpty) Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _renameVoice(SpeechVoice updated) async {
    setState(() => _previewVoice = null);
    final saved = await widget.onRename(updated);
    if (mounted && saved)
      setState(() {
        _renamed[updated.id] = updated.name;
        _voices = [
          for (final voice in _voices) voice.id == updated.id ? updated : voice,
        ];
      });
    return saved;
  }

  final _search = TextEditingController();
  SpeechVoiceFilter _voiceFilter = const SpeechVoiceFilter();
  Future<void> _chooseFilter() async {
    setState(() => _previewVoice = null);
    final filter = await showSpeechVoiceFilter(
      context,
      voices: _voices,
      selected: _voiceFilter,
    );
    if (mounted && filter != null) setState(() => _voiceFilter = filter);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final voices = [
      ..._voices.where((voice) => voice.id == widget.selected),
      ..._voices.where((voice) => voice.id != widget.selected),
    ];
    final filtered = voices
        .where(
          (voice) => _voiceFilter.matches(
            voice,
            voices.length < 20 ? '' : _search.text,
          ),
        )
        .toList();
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Text(
            '音色',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SettingsGlassAction(
                label: '关闭',
                icon: Icons.close_rounded,
                iconWidget: QuestionIcon(
                  type: QuestionIconType.close,
                  color: colors.onSurface,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ],
      ),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: .8,
        child: AppSheetSurface(
          child: SafeArea(
            top: false,
            child: AppSheetBody(
              header: header,
              child: Column(
                children: [
                  Expanded(
                    child: PaginationListener(
                      hasMore: !_loading && (widget.hasMore?.call() ?? false),
                      loadMore: _nextPage,
                      child: FloatingSearchLayout(
                        controller: _search,
                        trailingAction: SpeechVoiceFilter.available(voices)
                            ? SpeechVoiceFilterAction(
                                filter: _voiceFilter,
                                onPressed: _loading ? null : _chooseFilter,
                              )
                            : null,
                        hintText: '搜索音色',
                        enabled: !_loading && voices.length >= 20,
                        onChanged: (_) => setState(() => _previewVoice = null),
                        child: _loading
                            ? const Padding(
                                padding: EdgeInsets.only(top: 68),
                                child: SpeechVoiceListSkeleton(),
                              )
                            : filtered.isEmpty
                            ? const CustomScrollView(
                                physics: AlwaysScrollableScrollPhysics(),
                                slivers: [
                                  SliverFillRemaining(
                                    hasScrollBody: false,
                                    child: Center(
                                      child: EmptyDataView(title: '没有匹配的音色'),
                                    ),
                                  ),
                                ],
                              )
                            : Padding(
                                padding: EdgeInsets.zero,
                                child: DecoratedBox(
                                  decoration: const BoxDecoration(),
                                  child: ListView.separated(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    padding: EdgeInsets.only(
                                      top: 68,
                                      bottom: FloatingSearchLayout.clearance,
                                    ),
                                    separatorBuilder: (_, index) =>
                                        filtered[index].id == widget.selected ||
                                            filtered[index + 1].id ==
                                                widget.selected
                                        ? const SizedBox(height: 6)
                                        : Divider(
                                            height: 5,
                                            thickness: .5,
                                            indent: 76,
                                            endIndent: 16,
                                            color: colors.outlineVariant
                                                .withValues(alpha: .45),
                                          ),
                                    itemCount: filtered.length,
                                    itemBuilder: (context, index) {
                                      final voice = filtered[index];
                                      final selected =
                                          voice.id == widget.selected;
                                      return SpeechVoiceRow(
                                        key: ValueKey(voice.id),
                                        voice: voice,
                                        onRename: _renameVoice,
                                        detailsOnLongPress: true,
                                        selected: selected,
                                        onTap: () =>
                                            Navigator.pop(context, voice.id),
                                        preview: SpeechVoicePreview(
                                          account: widget.account,
                                          voice: voice,
                                          mode: _mode,
                                          text: _text,
                                          active: _previewVoice == voice.id,
                                          enabled:
                                              _mode ==
                                                  SpeechPreviewMode
                                                      .providerAudio ||
                                              widget.account.model.isNotEmpty,
                                          onActivate: () => setState(
                                            () => _previewVoice = voice.id,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
