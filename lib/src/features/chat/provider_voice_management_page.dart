import 'floating_search_layout.dart';
import 'speech_voice_filter.dart';
import 'speech_voice_pages.dart';
import 'list_sort_handle.dart';
import 'pagination_listener.dart';
import 'package:flutter/material.dart';
import '../../app/ui_action.dart';
import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import '../../domain/model_provider.dart';
import '../../domain/speech_voice.dart';
import '../../widgets/empty_data_view.dart';
import 'chat_controller.dart';
import 'conversation_menu_icon.dart';
import 'delete_confirmation_dialog.dart';
import 'glass_surface.dart';
import 'header_action_menu.dart';
import 'menu_press_highlight.dart';
import 'provider_named_value_dialog.dart';
import 'provider_settings_draft.dart';
import 'provider_voices_sheet.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'speech_voice_list_settings_page.dart';
import 'speech_voice_row.dart';
import 'speech_voice_list_skeleton.dart';
import 'speech_voice_details_sheet.dart';
import 'speech_preview_button.dart';
import 'speech_voice_preview_controller.dart';

class ProviderVoiceManagementPage extends StatefulWidget {
  const ProviderVoiceManagementPage({
    super.key,
    required this.controller,
    required this.draft,
    this.readOnly = false,
  });
  final ChatController controller;
  final ProviderSettingsDraft draft;
  final bool readOnly;
  @override
  State<ProviderVoiceManagementPage> createState() =>
      _ProviderVoiceManagementPageState();
}

class _ProviderVoiceManagementPageState
    extends State<ProviderVoiceManagementPage> {
  bool _saving = false;
  bool _editing = false;
  List<SpeechVoice>? _sortVoices;
  bool get _readOnly => widget.readOnly && !_editing;
  bool _loading = false;
  bool _failed = false;
  SpeechVoicePages? _pages;
  final _search = TextEditingController();
  SpeechVoiceFilter _voiceFilter = const SpeechVoiceFilter();
  Future<void> _chooseFilter() async {
    _preview.stop();
    final filter = await showSpeechVoiceFilter(
      context,
      voices: _voices,
      selected: _voiceFilter,
    );
    if (mounted && filter != null) setState(() => _voiceFilter = filter);
  }

  List<SpeechVoice> _remote = const [];
  late final _preview = SpeechVoicePreviewController(
    config: () => _config,
    voices: () => _voices,
  );
  void _previewChanged() => setState(() {});
  ModelConfig get _config => widget.readOnly
      ? widget.controller.modelSettings.profile(widget.draft.config.service)
      : widget.draft.config;
  @override
  void initState() {
    super.initState();
    _preview.addListener(_previewChanged);
    _loadFirst();
  }

  @override
  void dispose() {
    _pages?.dispose();
    _preview.dispose();
    _search.dispose();
    super.dispose();
  }

  List<SpeechVoice> get _voices => _config.speechApi?.autoSyncVoices == true
      ? _config.speechApi!.orderVoices(_remote)
      : _config.speechApi?.voices ?? const [];
  Future<void> _loadFirst() async {
    _pages?.dispose();
    _pages = null;
    final speech = _config.speechApi;
    if (speech == null || !speech.autoSyncVoices || speech.voiceList == null)
      return;
    final pages = SpeechVoicePages(_config);
    _pages = pages;
    setState(() {
      _remote = pages.voices;
      _loading = true;
      _failed = false;
    });
    try {
      await _loadNext();
    } on Object catch (error) {
      if (mounted) setState(() => _failed = true);
      if (mounted)
        ScaffoldMessenger.of(context).showToast(
          SnackBar(content: Text(errorMessage(error))),
          kind: ToastKind.error,
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadNext() async {
    final pages = _pages!;
    await pages.loadNext();
    if (!mounted || pages != _pages) return;
    setState(
      () => _remote = pages.voices
          .map((v) => v.renamed(pages.names[v.id] ?? v.name))
          .toList(),
    );
  }

  Future<bool> _save(Map<String, Object?> fields) async {
    setState(() => _saving = true);
    final saved = await runUiAction(context, () async {
      final draft = ProviderSettingsDraft(_config);
      draft.updateDetails({
        'speechApi': {..._config.speechApi!.toJson(), ...fields},
      });
      await saveProviderEditorConfig(
        widget.controller,
        widget.readOnly ? null : widget.draft,
        draft.config,
        defaultService: widget.controller.modelSettings.activeService,
      );
    });
    if (mounted) setState(() => _saving = false);
    return saved;
  }

  Future<void> _choose() async {
    _preview.stop();
    final result = await showModalBottomSheet<VoiceSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: ProviderVoicesSheet(config: _config),
      ),
    );
    if (!mounted || result == null) return;
    final saved = await _save({
      'voices': [for (final v in result.voices) v.toJson()],
      'voiceCatalog': [for (final v in result.catalog) v.toJson()],
      'autoSyncVoices': result.useAll,
    });
    if (mounted && saved) {
      setState(() => _remote = result.catalog);
      await _loadFirst();
    }
  }

  Future<void> _remove(SpeechVoice voice) async {
    _preview.stop();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => DeleteConfirmationDialog(
        title: '移除音色？',
        description: '移除“${voice.name}”后，这个音色将不再出现在选择列表中。',
        confirmLabel: '移除',
        cancelLabel: '取消',
      ),
    );
    if (!mounted || confirmed != true) return;
    await _save({
      'voices': [
        for (final v in _voices)
          if (v.id != voice.id) v.toJson(),
      ],
      'autoSyncVoices': false,
    });
  }

  Future<void> _rename(SpeechVoice voice) async {
    _preview.stop();
    final renamed = await editProviderNamedValue(
      context,
      title: '修改音色名称',
      valueLabel: '接口名称',
      initial: (id: voice.id, name: voice.name),
      editValue: false,
    );
    if (!mounted || renamed == null || renamed.name == voice.name) return;
    await _saveVoiceName(voice.renamed(renamed.name));
  }

  Future<bool> _saveVoiceName(SpeechVoice updated) async {
    _preview.stop();
    final speech = _config.speechApi!;
    final catalog = {
      for (final entry in speech.voiceCatalog) entry.id: entry,
      for (final entry in _voices) entry.id: entry,
      updated.id: updated,
    }.values;
    final saved = await _save({
      'voices': [
        for (final entry in speech.voices)
          (entry.id == updated.id ? updated : entry).toJson(),
      ],
      'voiceCatalog': [for (final entry in catalog) entry.toJson()],
    });
    if (mounted && saved)
      setState(() {
        _pages?.names[updated.id] = updated.name;
        _remote = [
          for (final entry in _remote) entry.id == updated.id ? updated : entry,
        ];
      });
    return saved;
  }

  Future<void> _menu(BuildContext anchor) async {
    final action = await showHeaderActionMenu(
      anchor,
      items: [
        if (_voices.isNotEmpty)
          (
            value: 'sort',
            label: '调整顺序',
            icon: const SettingsIcon(type: SettingsIconType.sort),
          ),
        (
          value: 'api',
          label: '音色列表接口配置',
          icon: const SettingsIcon(type: SettingsIconType.field),
        ),
      ],
    );
    if (!mounted) return;
    if (action == 'sort') {
      _preview.stop();
      FocusScope.of(context).unfocus();
      setState(() {
        _search.clear();
        _sortVoices = [..._voices];
      });
    }
    if (action == 'api') {
      _preview.stop();
      final draft = ProviderSettingsDraft(_config);
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => SpeechVoiceListSettingsPage(draft: draft),
        ),
      );
      if (!mounted || !draft.differsFrom(_config)) return;
      final saved = await _save({
        'voiceList': draft.config.speechApi!.voiceList?.toJson(),
      });
      if (mounted && saved) await _loadFirst();
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = _config.speechApi;
    final allVoices = _voices;
    final hasSearch = _sortVoices == null && allVoices.length >= 20;
    final query = allVoices.length >= 20
        ? _search.text.trim().toLowerCase()
        : '';
    final voices =
        _sortVoices ??
        allVoices.where((voice) => _voiceFilter.matches(voice, query)).toList();
    final colors = Theme.of(context).colorScheme;
    final previewAccount = api == null ? null : _preview.account;
    return PopScope(
      canPop: _sortVoices == null && !_saving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_saving && _sortVoices != null) {
          setState(() => _sortVoices = null);
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: SettingsAppBar(
          title: _sortVoices != null
              ? '音色排序'
              : widget.readOnly && _editing
              ? ''
              : '音色管理',
          onBack: _saving
              ? null
              : () {
                  if (_sortVoices != null) {
                    setState(() => _sortVoices = null);
                  } else {
                    Navigator.pop(context);
                  }
                },
          actions: [
            if (_sortVoices != null)
              SettingsGlassAction(
                label: '完成排序',
                icon: Icons.check_rounded,
                iconWidget: const SettingsIcon(type: SettingsIconType.check),
                onPressed: _saving
                    ? null
                    : () async {
                        final ordered = {
                          for (final voice in _sortVoices!) voice.id: voice,
                          for (final voice in _config.speechApi!.voices)
                            if (!_sortVoices!.any(
                              (item) => item.id == voice.id,
                            ))
                              voice.id: voice,
                        }.values;
                        final saved = await _save({
                          'voices': [
                            for (final voice in ordered) voice.toJson(),
                          ],
                        });
                        if (mounted && saved)
                          setState(() => _sortVoices = null);
                      },
              )
            else
              SettingsGlassActionSurface(
                child: SizedBox(
                  height: 40,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.readOnly) ...[
                        RoundAction(
                          label: _editing ? '完成' : '编辑',
                          icon: _editing
                              ? Icons.check_rounded
                              : Icons.edit_outlined,
                          iconWidget: _editing
                              ? const SettingsIcon(type: SettingsIconType.check)
                              : const ConversationMenuIcon(
                                  type: ConversationMenuIconType.rename,
                                ),
                          onPressed: _saving
                              ? null
                              : () => setState(() => _editing = !_editing),
                        ),
                        VerticalDivider(
                          width: 1,
                          thickness: 1,
                          indent: 10,
                          endIndent: 10,
                          color: colors.onSurface.withValues(alpha: .12),
                        ),
                      ],
                      if (!_readOnly) ...[
                        RoundAction(
                          label: '添加音色',
                          icon: Icons.add_rounded,
                          iconWidget: const SettingsIcon(
                            type: SettingsIconType.add,
                          ),
                          onPressed: _saving || _loading || api == null
                              ? null
                              : _choose,
                        ),
                        VerticalDivider(
                          width: 1,
                          thickness: 1,
                          indent: 10,
                          endIndent: 10,
                          color: colors.onSurface.withValues(alpha: .12),
                        ),
                      ],
                      Builder(
                        builder: (anchor) => RoundAction(
                          label: '更多',
                          icon: Icons.more_vert,
                          iconWidget: const SettingsIcon(
                            type: SettingsIconType.more,
                          ),
                          onPressed: _saving || _loading || api == null
                              ? null
                              : () => _menu(anchor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        body: SettingsPageBody(
          child: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  children: [
                    Expanded(
                      child: PaginationListener(
                        hasMore:
                            _sortVoices == null &&
                            !_loading &&
                            api?.autoSyncVoices == true &&
                            (_pages?.hasMore ?? false),
                        loadMore: _loadNext,
                        failed: _failed,
                        onRetry: _failed ? _loadFirst : null,
                        child: FloatingSearchLayout(
                          controller: _search,
                          trailingAction:
                              _sortVoices == null &&
                                  SpeechVoiceFilter.available(allVoices)
                              ? SpeechVoiceFilterAction(
                                  filter: _voiceFilter,
                                  onPressed: _saving || _loading
                                      ? null
                                      : _chooseFilter,
                                )
                              : null,
                          onChanged: (_) {
                            _preview.stop();
                            setState(() {});
                          },
                          hintText: '搜索已选音色',
                          enabled: hasSearch,
                          bottom: 16,
                          child: CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              SliverPadding(
                                padding: settingsPagePadding(
                                  context,
                                  const EdgeInsets.only(top: 12),
                                ),
                                sliver: const SliverToBoxAdapter(
                                  child: SizedBox.shrink(),
                                ),
                              ),
                              if (_loading && allVoices.isEmpty)
                                const SliverToBoxAdapter(
                                  child: SpeechVoiceListSkeleton(),
                                )
                              else if (voices.isEmpty)
                                SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: Center(
                                    child: EmptyDataView(
                                      title: allVoices.isNotEmpty
                                          ? '没有匹配的音色'
                                          : api == null
                                          ? '请先配置语音接口'
                                          : '还没有添加的音色',
                                      actionText:
                                          !_readOnly &&
                                              allVoices.isEmpty &&
                                              api != null
                                          ? '添加音色'
                                          : null,
                                      onAction: _choose,
                                    ),
                                  ),
                                )
                              else
                                SliverPadding(
                                  padding: EdgeInsets.fromLTRB(
                                    4,
                                    0,
                                    4,
                                    hasSearch
                                        ? FloatingSearchLayout.clearance
                                        : 16,
                                  ),
                                  sliver: SliverReorderableList(
                                    onReorderItem: (oldIndex, newIndex) =>
                                        setState(() {
                                          _sortVoices!.insert(
                                            newIndex,
                                            _sortVoices!.removeAt(oldIndex),
                                          );
                                        }),
                                    proxyDecorator: (child, index, animation) =>
                                        child,
                                    itemCount: voices.length,
                                    itemBuilder: (_, index) {
                                      final voice = voices[index];
                                      return Builder(
                                        key: ValueKey(voice.id),
                                        builder: (anchor) => MenuPressHighlight(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          onLongPressStart:
                                              _saving ||
                                                  _readOnly ||
                                                  _sortVoices != null
                                              ? null
                                              : (details) async {
                                                  final action = await showHeaderActionMenu(
                                                    anchor,
                                                    position:
                                                        details.globalPosition,
                                                    destructiveValues: const {
                                                      'remove',
                                                    },
                                                    items: [
                                                      (
                                                        value: 'rename',
                                                        label: '修改名称',
                                                        icon: const ConversationMenuIcon(
                                                          type:
                                                              ConversationMenuIconType
                                                                  .rename,
                                                        ),
                                                      ),
                                                      (
                                                        value: 'remove',
                                                        label: '移除音色',
                                                        icon: const ConversationMenuIcon(
                                                          type:
                                                              ConversationMenuIconType
                                                                  .delete,
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                  if (mounted &&
                                                      action == 'remove')
                                                    await _remove(voice);
                                                  if (mounted &&
                                                      action == 'rename')
                                                    await _rename(voice);
                                                },
                                          child: SpeechVoiceRow(
                                            key: ValueKey(voice.id),
                                            voice: voice,
                                            selected: false,
                                            onTap:
                                                _saving || _sortVoices != null
                                                ? null
                                                : () {
                                                    _preview.stop();
                                                    showSpeechVoiceDetails(
                                                      context,
                                                      voice,
                                                      onRename: _readOnly
                                                          ? null
                                                          : _saveVoiceName,
                                                    );
                                                  },
                                            preview: _sortVoices != null
                                                ? ListSortHandle(
                                                    index: index,
                                                    enabled: !_saving,
                                                  )
                                                : SpeechVoicePreview(
                                                    account: previewAccount!,
                                                    voice: voice,
                                                    mode: _preview.mode,
                                                    text: _preview.text,
                                                    active:
                                                        _preview.voice ==
                                                        voice.id,
                                                    enabled: !_saving,
                                                    onActivate: () =>
                                                        _preview.activate(
                                                          context,
                                                          voice.id,
                                                        ),
                                                  ),
                                            onRename: _readOnly
                                                ? null
                                                : _saveVoiceName,
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
