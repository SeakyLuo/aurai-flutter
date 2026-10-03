import 'floating_search_layout.dart';
import 'speech_voice_filter.dart';
import 'speech_voice_pages.dart';
import 'pagination_listener.dart';
import 'package:flutter/material.dart';
import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import '../../domain/model_provider.dart';
import '../../providers/speech_voice_catalog.dart';
import '../../widgets/empty_data_view.dart';
import 'glass_surface.dart';
import 'header_action_menu.dart';
import 'question_icon.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'speech_voice_row.dart';
import 'speech_voice_list_skeleton.dart';
import 'speech_preview_button.dart';
import 'speech_voice_preview_controller.dart';

typedef VoiceSelection = ({
  bool useAll,
  List<SpeechVoice> voices,
  List<SpeechVoice> catalog,
});

class ProviderVoicesSheet extends StatefulWidget {
  const ProviderVoicesSheet({super.key, required this.config});
  final ModelConfig config;
  @override
  State<ProviderVoicesSheet> createState() => _ProviderVoicesSheetState();
}

class _ProviderVoicesSheetState extends State<ProviderVoicesSheet> {
  final _search = TextEditingController();
  SpeechVoiceFilter _voiceFilter = const SpeechVoiceFilter();
  Future<void> _chooseFilter() async {
    _preview.stop();
    final filter = await showSpeechVoiceFilter(
      context,
      voices: _available,
      selected: _voiceFilter,
    );
    if (mounted && filter != null) setState(() => _voiceFilter = filter);
  }

  late final _pages = SpeechVoicePages(widget.config);
  late final _selected = widget.config.speechApi!.voices
      .map((v) => v.id)
      .toSet();
  late bool _useAll = widget.config.speechApi!.autoSyncVoices;
  List<SpeechVoice> get _catalog => _pages.voices;
  final _renamed = <String, String>{};
  bool _loading = true,
      _changed = false,
      _failed = false,
      _selectedOnly = false;
  final _filteredSelection = <String>{};
  late final _preview = SpeechVoicePreviewController(
    config: () => widget.config,
    voices: () => _available,
  );
  void _previewChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    _preview.addListener(_previewChanged);
    _pages.addListener(_previewChanged);
    _load();
  }

  @override
  void dispose() {
    _pages.dispose();
    _preview.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _preview.stop();
    setState(() => _loading = true);
    try {
      await _pages.loadNext();
      if (mounted)
        setState(() {
          _failed = false;
        });
    } on Object catch (error) {
      if (mounted) {
        setState(() => _failed = true);
        ScaffoldMessenger.of(context).showToast(
          SnackBar(content: Text(errorMessage(error))),
          kind: ToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<SpeechVoice> get _available => SpeechVoiceCatalog.merge(
    _catalog,
    _selectedOnly ? widget.config.speechApi!.voices : const [],
  ).map((voice) => voice.renamed(_renamed[voice.id] ?? voice.name)).toList();

  Future<bool> _renameVoice(SpeechVoice updated) async {
    _preview.stop();
    setState(() {
      _renamed[updated.id] = updated.name;
      _changed = true;
    });
    return true;
  }

  void _save() {
    final catalog = {
      for (final voice in widget.config.speechApi!.voiceCatalog)
        voice.id: voice,
      for (final voice in widget.config.speechApi!.voices) voice.id: voice,
      for (final voice in _available) voice.id: voice,
    }.values.map((v) => v.renamed(_renamed[v.id] ?? v.name)).toList();
    Navigator.pop(context, (
      useAll: _useAll,
      voices: catalog
          .where((v) => _useAll || _selected.contains(v.id))
          .toList(),
      catalog: catalog,
    ));
  }

  Future<void> _filter(BuildContext anchor) async {
    final action = await showHeaderActionMenu(
      anchor,
      items: [
        if (!_useAll)
          (
            value: 'selected',
            label: _selectedOnly ? '显示全部音色' : '只看已选音色',
            icon: const SettingsIcon(type: SettingsIconType.check),
          ),
        (
          value: 'all',
          label: _useAll ? '关闭使用全部' : '使用全部音色',
          icon: const SettingsIcon(type: SettingsIconType.grid),
        ),
      ],
    );
    if (!mounted || action == null) return;
    _preview.stop();
    setState(() {
      if (action == 'selected') {
        _selectedOnly = !_selectedOnly;
        _filteredSelection.clear();
        if (_selectedOnly) _filteredSelection.addAll(_selected);
      } else {
        if (_useAll) _selected.addAll(_available.map((v) => v.id));
        _useAll = !_useAll;
        _selectedOnly = false;
        _changed = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final query = _available.length >= 20
        ? _search.text.trim().toLowerCase()
        : '';
    final shown = _available
        .where(
          (v) =>
              (!_selectedOnly || _filteredSelection.contains(v.id)) &&
              _voiceFilter.matches(v, query),
        )
        .toList();
    final canSave = _changed && !_loading && !_failed;
    final previewAccount = _preview.account;
    return FractionallySizedBox(
      heightFactor: .8,
      child: SafeArea(
        top: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: SearchSheetBody(
                header: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 108),
                          child: Center(
                            child: Text(
                              '音色',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          SettingsGlassAction(
                            label: '关闭',
                            icon: Icons.close_rounded,
                            iconWidget: const QuestionIcon(
                              type: QuestionIconType.close,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Spacer(),
                          SettingsGlassActionSurface(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                RoundAction(
                                  label: '保存',
                                  icon: Icons.check_rounded,
                                  iconWidget: SettingsIcon(
                                    type: SettingsIconType.check,
                                    color: colors.onSurface.withValues(
                                      alpha: canSave ? 1 : .3,
                                    ),
                                  ),
                                  onPressed: canSave ? _save : null,
                                ),
                                SizedBox(
                                  height: 18,
                                  child: VerticalDivider(
                                    width: 1,
                                    color: colors.outlineVariant,
                                  ),
                                ),
                                Builder(
                                  builder: (anchor) => RoundAction(
                                    label: '更多',
                                    icon: Icons.more_vert,
                                    iconWidget: const SettingsIcon(
                                      type: SettingsIconType.more,
                                    ),
                                    onPressed: _loading || _failed
                                        ? null
                                        : () => _filter(anchor),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                child: PaginationListener(
                  hasMore: _pages.hasMore && !_loading && !_selectedOnly,
                  loadMore: _pages.loadNext,
                  failed: _failed,
                  onRetry: _load,
                  child: FloatingSearchLayout(
                    controller: _search,
                    trailingAction: SpeechVoiceFilter.available(_available)
                        ? SpeechVoiceFilterAction(
                            filter: _voiceFilter,
                            onPressed: _loading || _failed
                                ? null
                                : _chooseFilter,
                          )
                        : null,
                    onChanged: (_) {
                      _preview.stop();
                      setState(() {});
                    },
                    hintText: '搜索音色',
                    enabled: _available.length >= 20,
                    bottom: _useAll ? 16 : 64,
                    child: _loading && _catalog.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.only(top: 68),
                            child: SpeechVoiceListSkeleton(),
                          )
                        : CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              if (shown.isEmpty)
                                SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: Center(
                                    child: EmptyDataView(
                                      title: query.isNotEmpty
                                          ? '没有匹配的音色'
                                          : _selectedOnly
                                          ? '暂无已选音色'
                                          : '暂无可用音色',
                                    ),
                                  ),
                                )
                              else
                                SliverPadding(
                                  padding: EdgeInsets.only(
                                    top: 68,
                                    bottom: _available.length >= 20
                                        ? (_useAll
                                              ? FloatingSearchLayout.clearance
                                              : 144)
                                        : (_useAll ? 16 : 72),
                                  ),
                                  sliver: SliverList.builder(
                                    itemCount: shown.length,
                                    itemBuilder: (_, index) {
                                      final voice = shown[index];
                                      final selected =
                                          _useAll ||
                                          _selected.contains(voice.id);
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 6,
                                        ),
                                        child: SpeechVoiceRow(
                                          key: ValueKey(voice.id),
                                          voice: voice,
                                          onRename: _renameVoice,
                                          detailsOnLongPress: true,
                                          selected: selected,
                                          onTap: _useAll || _failed
                                              ? null
                                              : () => setState(() {
                                                  if (!_selected.remove(
                                                    voice.id,
                                                  ))
                                                    _selected.add(voice.id);
                                                  _changed = true;
                                                }),
                                          preview: SpeechVoicePreview(
                                            account: previewAccount,
                                            voice: voice,
                                            mode: _preview.mode,
                                            text: _preview.text,
                                            active: _preview.voice == voice.id,
                                            enabled: !_failed,
                                            onActivate: () => _preview.activate(
                                              context,
                                              voice.id,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
            if (!_useAll)
              Positioned(
                left: 12,
                right: 12,
                bottom: 8,
                child: GlassSurface(
                  radius: 26,
                  tintOpacity: .65,
                  shadowOpacity: 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 2, 16, 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '已选 ${_selected.length} 个音色',
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: colors.onSurface,
                          ),
                          onPressed: _loading || _failed || shown.isEmpty
                              ? null
                              : () => setState(() {
                                  final ids = shown.map((v) => v.id);
                                  if (ids.every(_selected.contains))
                                    _selected.removeAll(ids);
                                  else
                                    _selected.addAll(ids);
                                  _changed = true;
                                }),
                          child: Text(
                            shown.isNotEmpty &&
                                    shown.every((v) => _selected.contains(v.id))
                                ? '取消全选'
                                : '全选',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
