import '../features/chat/library_detail_split.dart';
import '../features/chat/floating_search_layout.dart';
import '../widgets/empty_data_view.dart';
import 'miniapp_recent_page.dart';
import 'miniapp_launcher.dart';
import '../features/chat/settings_icon.dart';
import 'miniapp_icon.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../app/glass_notice.dart';
import '../domain/error_message.dart';
import '../features/chat/chat_controller.dart';
import '../features/chat/settings_appearance.dart';
import '../features/chat/search_skeleton.dart';
import '../features/chat/pagination_listener.dart';
import 'miniapp_detail_page.dart';
import 'miniapp_library_store.dart';
import 'miniapp_message_catalog.dart';

class MiniappLibraryPage extends StatefulWidget {
  const MiniappLibraryPage({
    super.key,
    required this.controller,
    this.pickingMessage = false,
  });
  final ChatController controller;
  final bool pickingMessage;

  @override
  State<MiniappLibraryPage> createState() => _MiniappLibraryPageState();
}

class _MiniappLibraryPageState extends State<MiniappLibraryPage> {
  final _detailSplitKey = GlobalKey<LibraryDetailSplitState>();
  late final _store = MiniappLibraryStore(widget.controller.htmlStore.database);
  final _search = TextEditingController();
  List<MiniappEntry> _bundled = [], _apps = [], _recent = [], _locals = [];
  bool _localMore = false, _opening = false;
  bool _loading = true, _more = false, _failed = false;
  int _generation = 0;
  Timer? _debounce;
  final _messageCapable = <String>{};

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    if (!widget.pickingMessage) _loadRecent();
  }

  Future<void> _load({required bool reset, bool refresh = false}) async {
    if (!reset && !refresh && (_loading || (!_more && !_localMore))) return;
    final replace = reset || refresh;
    final appLimit = refresh && _apps.length > 50 ? _apps.length : 50;
    final localLimit = refresh && _locals.length > 50 ? _locals.length : 50;
    final generation = ++_generation;
    final query = _search.text.trim();
    setState(() {
      _loading = true;
      _failed = false;
      if (reset) {
        _apps = [];
        _locals = [];
        _localMore = false;
        _more = false;
      }
    });
    try {
      final bundled = await _store.bundled();
      final pages = await Future.wait([
        if (replace || _more)
          _store.page(
            bundledIds: bundled.map((e) => e.id).toList(),
            after: replace || _apps.isEmpty ? null : _apps.last,
            limit: appLimit,
            query: query,
          )
        else
          Future.value((entries: <MiniappEntry>[], more: false)),
        if (query.isNotEmpty || widget.pickingMessage)
          if (replace || _localMore)
            _store.page(
              bundledIds: widget.pickingMessage
                  ? bundled.map((e) => e.id).toList()
                  : const [],
              mine: true,
              after: replace || _locals.isEmpty ? null : _locals.last,
              limit: localLimit,
              query: query,
            )
          else
            Future.value((entries: <MiniappEntry>[], more: false)),
      ]);
      final page = pages.first;
      final capable = widget.pickingMessage
          ? await _store.messageCapable([
              ...bundled,
              ...page.entries,
              ...pages[1].entries,
            ])
          : const <String>{};
      if (!mounted || generation != _generation) return;
      setState(() {
        _bundled = bundled;
        if (replace) _messageCapable.clear();
        _messageCapable.addAll(capable);
        _apps = replace ? page.entries : [..._apps, ...page.entries];
        _more = page.more;
        _locals = query.isEmpty && !widget.pickingMessage
            ? []
            : replace
            ? pages[1].entries
            : [..._locals, ...pages[1].entries];
        _localMore =
            (query.isNotEmpty || widget.pickingMessage) && pages[1].more;
      });
    } on Object catch (error) {
      if (mounted && generation == _generation) {
        _failed = true;
        ScaffoldMessenger.of(context).showToast(
          SnackBar(content: Text(errorMessage(error))),
          kind: ToastKind.error,
        );
      }
    } finally {
      if (mounted && generation == _generation)
        setState(() => _loading = false);
    }
  }

  Future<void> _loadRecent() async {
    try {
      final result = await _store.recent(limit: 4);
      if (mounted) setState(() => _recent = result.entries);
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showToast(
          SnackBar(content: Text(errorMessage(error))),
          kind: ToastKind.error,
        );
    }
  }

  Future<void> _openRecent(MiniappEntry entry) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await openMiniapp(context, entry, widget.controller.htmlStore);
      if (mounted) await _loadRecent();
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showToast(
          SnackBar(content: Text(errorMessage(error))),
          kind: ToastKind.error,
        );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Widget _recentSection() => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Material(
      color: settingsFieldColor(context),
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsetsDirectional.only(
              start: 18,
              end: 12,
            ),
            title: const Text(
              '最近使用',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            trailing: const SettingsIcon(type: SettingsIconType.chevron),
            onTap: _opening
                ? null
                : () async {
                    await Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MiniappRecentPage(
                          store: widget.controller.htmlStore,
                        ),
                      ),
                    );
                    if (mounted) await _loadRecent();
                  },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < 4; i++)
                  Expanded(
                    child: i >= _recent.length
                        ? const SizedBox()
                        : InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: _opening
                                ? null
                                : () => _openRecent(_recent[i]),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 8,
                              ),
                              child: Column(
                                children: [
                                  MiniappIcon(
                                    path: _recent[i].iconPath,
                                    asset: _recent[i].iconAsset,
                                    size: 52,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _recent[i].title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
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
        ],
      ),
    ),
  );

  void _queryChanged(String value) {
    _debounce?.cancel();
    ++_generation;
    setState(() {
      _loading = true;
      _apps = [];
      _locals = [];
      _localMore = false;
      _more = false;
    });
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => _load(reset: true),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Widget _tile(MiniappEntry entry) => Material(
    color: settingsFieldColor(context),
    borderRadius: BorderRadius.circular(22),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      leading: MiniappIcon(
        path: entry.iconPath,
        asset: entry.iconAsset,
        size: 48,
      ),
      horizontalTitleGap: 14,
      titleAlignment: ListTileTitleAlignment.center,
      title: Text(
        entry.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: entry.description.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                entry.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
      onTap: _opening
          ? null
          : () async {
              if (widget.pickingMessage) {
                Navigator.pop(context, entry);
                return;
              }
              if (entry.kind != MiniappKind.published) {
                await _openRecent(entry);
                return;
              }
              await _detailSplitKey.currentState!.open(
                MaterialPageRoute(
                  builder: (_) => MiniappDetailPage(
                    entry: entry,
                    store: widget.controller.htmlStore,
                  ),
                ),
              );
              if (mounted) {
                _load(reset: false, refresh: true);
                _loadRecent();
              }
            },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final byId = <String, MiniappEntry>{
      for (final entry in [
        ..._bundled.where((e) => e.title.toLowerCase().contains(query)),
        ..._apps,
        ..._locals,
      ])
        entry.publicationId: entry,
    };
    final entries =
        byId.values
            .where(
              (e) =>
                  !widget.pickingMessage ||
                  _messageCapable.contains('${e.kind.name}:${e.id}'),
            )
            .toList()
          ..sort((a, b) {
            final aTime = a.updatedAt;
            final bTime = b.updatedAt;
            if (aTime == null && bTime != null) return 1;
            if (aTime != null && bTime == null) return -1;
            final timeOrder = aTime == null ? 0 : bTime!.compareTo(aTime);
            return timeOrder != 0
                ? timeOrder
                : a.publicationId.compareTo(b.publicationId);
          });
    return LibraryDetailSplit(
      key: _detailSplitKey,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: SettingsAppBar(
          title: widget.pickingMessage ? '选择要发送的小程序' : '小程序',
          onBack: () => Navigator.pop(context),
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
                      child: FloatingSearchLayout(
                        itemCount: {
                          for (final entry in [
                            ..._bundled,
                            ..._apps,
                            ..._locals,
                          ])
                            if (!widget.pickingMessage ||
                                _messageCapable.contains(
                                  '${entry.kind.name}:${entry.id}',
                                ))
                              entry.publicationId,
                        }.length,
                        controller: _search,
                        onChanged: _queryChanged,
                        hintText: '搜索小程序',
                        enabled: true,
                        bottom: 16,
                        child: PaginationListener(
                          failed: _failed,
                          onRetry: () => _load(reset: !_more && !_localMore),
                          hasMore:
                              !_loading && !_failed && (_more || _localMore),
                          loadMore: () => _load(reset: false),
                          child: CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),

                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,

                            slivers: [
                              SliverPadding(
                                padding: settingsPagePadding(
                                  context,
                                  const EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    16,
                                    FloatingSearchLayout.clearance,
                                  ),
                                ),
                                sliver: SliverMainAxisGroup(
                                  slivers: [
                                    SliverList.list(
                                      children: [
                                        if (!widget.pickingMessage &&
                                            query.isEmpty &&
                                            _recent.isNotEmpty)
                                          _recentSection(),
                                        if (!widget.pickingMessage)
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              8,
                                              0,
                                              8,
                                              14,
                                            ),
                                            child: Text(
                                              query.isEmpty ? '发现小程序' : '搜索结果',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                        if (_loading && entries.isEmpty)
                                          const Padding(
                                            padding: EdgeInsets.all(16),
                                            child: SearchSkeleton(
                                              label: '正在加载小程序',
                                              avatarSize: 48,
                                            ),
                                          ),

                                        for (final entry in entries)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            child: _tile(entry),
                                          ),
                                        if (_loading && entries.isNotEmpty)
                                          const Padding(
                                            padding: EdgeInsets.all(16),
                                            child: Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (!_loading && entries.isEmpty)
                                      SliverFillRemaining(
                                        hasScrollBody: false,
                                        child: Padding(
                                          padding: const EdgeInsets.all(32),
                                          child: Center(
                                            child: EmptyDataView(
                                              title: query.isEmpty
                                                  ? (widget.pickingMessage
                                                        ? '暂无可发送的小程序'
                                                        : '暂无已发布的小程序')
                                                  : '没有匹配的小程序',
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
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
