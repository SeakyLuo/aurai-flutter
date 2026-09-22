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
import '../features/chat/sidebar_action_icon.dart';
import '../features/chat/member_avatar.dart';
import 'miniapp_detail_page.dart';
import 'miniapp_library_store.dart';

class MiniappLibraryPage extends StatefulWidget {
  const MiniappLibraryPage({super.key, required this.controller});
  final ChatController controller;

  @override
  State<MiniappLibraryPage> createState() => _MiniappLibraryPageState();
}

class _MiniappLibraryPageState extends State<MiniappLibraryPage> {
  late final _store = MiniappLibraryStore(widget.controller.htmlGames.database);
  final _search = TextEditingController();
  List<MiniappEntry> _bundled = [], _apps = [], _recent = [], _locals = [];
  bool _localMore = false, _opening = false;
  bool _loading = true, _more = false;
  int _generation = 0;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _loadRecent();
  }

  Future<void> _load({required bool reset}) async {
    final generation = ++_generation;
    final query = _search.text.trim();
    setState(() {
      _loading = true;
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
        if (reset || _more)
          _store.page(
            bundledIds: bundled.map((e) => e.id).toList(),
            after: reset || _apps.isEmpty ? null : _apps.last,
            query: query,
          )
        else
          Future.value((entries: <MiniappEntry>[], more: false)),
        if (query.isNotEmpty)
          if (reset || _localMore)
            _store.page(
              bundledIds: const [],
              mine: true,
              after: reset || _locals.isEmpty ? null : _locals.last,
              query: query,
            )
          else
            Future.value((entries: <MiniappEntry>[], more: false)),
      ]);
      final page = pages.first;
      if (!mounted || generation != _generation) return;
      setState(() {
        _bundled = bundled;
        _apps = reset ? page.entries : [..._apps, ...page.entries];
        _more = page.more;
        _locals = query.isEmpty
            ? []
            : reset
            ? pages[1].entries
            : [..._locals, ...pages[1].entries];
        _localMore = query.isNotEmpty && pages[1].more;
      });
    } on Object catch (error) {
      if (mounted && generation == _generation) {
        ScaffoldMessenger.of(
          context,
        ).showGlassSnackBar(SnackBar(content: Text(errorMessage(error))));
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
        ScaffoldMessenger.of(
          context,
        ).showGlassSnackBar(SnackBar(content: Text(errorMessage(error))));
    }
  }

  Future<void> _openRecent(MiniappEntry entry) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await openMiniapp(context, entry, widget.controller.htmlGames);
      if (mounted) await _loadRecent();
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showGlassSnackBar(SnackBar(content: Text(errorMessage(error))));
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
                          store: widget.controller.htmlGames,
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
      title: Row(
        children: [
          MiniappIcon(path: entry.iconPath, asset: entry.iconAsset),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.title,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.description.isNotEmpty) ...[
              Text(
                entry.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                if (entry.publisherProfile != null) ...[
                  MemberAvatar(sender: entry.publisherProfile!, size: 24),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    entry.publisher,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      onTap: _opening
          ? null
          : () async {
              if (entry.kind != MiniappKind.published) {
                await _openRecent(entry);
                return;
              }
              await Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => MiniappDetailPage(
                    entry: entry,
                    store: widget.controller.htmlGames,
                  ),
                ),
              );
              if (mounted) {
                _load(reset: true);
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
    final entries = byId.values.toList();
    return Scaffold(
      appBar: SettingsAppBar(
        title: '小程序',
        onBack: () => Navigator.pop(context),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    controller: _search,
                    onChanged: _queryChanged,
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    decoration: InputDecoration(
                      hintText: '搜索小程序',
                      filled: true,
                      fillColor: settingsFieldColor(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(26),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.all(13),
                        child: SidebarActionIcon(
                          type: SidebarActionIconType.search,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      if (query.isEmpty && _recent.isNotEmpty) _recentSection(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 14),
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
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      if (!_loading && entries.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              query.isEmpty ? '暂无已发布的小程序' : '没有匹配的小程序',
                            ),
                          ),
                        ),
                      for (final entry in entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _tile(entry),
                        ),
                      if (_more || _localMore)
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () => _load(reset: false),
                          child: Text(_loading ? '正在加载' : '加载更多'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
