import '../features/chat/search_skeleton.dart';
import 'package:flutter/material.dart';

import '../app/glass_notice.dart';
import '../domain/error_message.dart';
import '../features/chat/animated_entry_list.dart';
import '../features/chat/chat_controller.dart';
import '../features/chat/header_action_menu.dart';
import '../features/chat/settings_appearance.dart';
import '../features/chat/settings_icon.dart';
import 'miniapp_detail_page.dart';
import 'miniapp_favorites.dart';
import 'miniapp_icon.dart';
import 'miniapp_library_page.dart';
import 'miniapp_library_store.dart';

class MiniappFavoritesList extends StatefulWidget {
  const MiniappFavoritesList({super.key, required this.controller});
  final ChatController controller;

  @override
  State<MiniappFavoritesList> createState() => _MiniappFavoritesListState();
}

class _MiniappFavoritesListState extends State<MiniappFavoritesList> {
  late final _store = MiniappFavorites(widget.controller.htmlGames.database);
  final _scroll = ScrollController();
  final _items = <MiniappFavorite>[];
  bool _loading = false, _more = true, _failed = false;
  String? _opening;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 300 && !_failed) _load();
  }

  void _notice(Object error) => ScaffoldMessenger.of(
    context,
  ).showGlassSnackBar(SnackBar(content: Text(errorMessage(error))));

  Future<void> _load({bool reset = false}) async {
    if (_loading || (!reset && !_more)) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final items = await _store.page(offset: reset ? 0 : _items.length);
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(items);
        _more = items.length == 50;
      });
    } on Object catch (error) {
      if (mounted) {
        _failed = true;
        _notice(error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(MiniappFavorite item) async {
    if (_opening != null) return;
    setState(() => _opening = _store.key(item.entry));
    try {
      final entry = await MiniappLibraryStore(
        widget.controller.htmlGames.database,
      ).refresh(item.entry);
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => MiniappDetailPage(
            entry: entry,
            store: widget.controller.htmlGames,
          ),
        ),
      );
      if (mounted) await _load(reset: true);
    } on Object catch (error) {
      if (mounted) _notice(error);
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  Future<void> _remove(MiniappFavorite item) async {
    try {
      await _store.remove(item.entry);
      if (!mounted) return;
      setState(() => _items.remove(item));
      ScaffoldMessenger.of(context).showGlassSnackBar(
        SnackBar(
          content: const Text('已取消收藏'),
          duration: const Duration(seconds: 6),
          persist: false,
          action: SnackBarAction(
            label: '撤销',
            onPressed: () async {
              try {
                await _store.add(item.entry, starredAt: item.starredAt);
                if (!mounted) return;
                setState(() {
                  if (_items.any(
                    (other) =>
                        _store.key(other.entry) == _store.key(item.entry),
                  ))
                    return;
                  _items.add(item);
                  _items.sort((a, b) {
                    final time = b.starredAt.compareTo(a.starredAt);
                    return time != 0
                        ? time
                        : _store.key(b.entry).compareTo(_store.key(a.entry));
                  });
                });
              } on Object catch (error) {
                if (mounted) _notice(error);
              }
            },
          ),
        ),
      );
    } on Object catch (error) {
      if (mounted) _notice(error);
    }
  }

  Future<void> _menu(BuildContext anchor, MiniappFavorite item) async {
    final selected = await showHeaderActionMenu(
      anchor,
      items: [
        (
          value: 'remove',
          label: '取消收藏',
          icon: const SettingsIcon(
            type: SettingsIconType.starFilled,
            color: Color(0xffe5ad24),
          ),
        ),
      ],
    );
    if (mounted && selected == 'remove') await _remove(item);
  }

  Future<void> _library() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => MiniappLibraryPage(controller: widget.controller),
      ),
    );
    if (mounted) await _load(reset: true);
  }

  Widget _tile(MiniappFavorite item) => Padding(
    key: ValueKey(_store.key(item.entry)),
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: settingsFieldColor(context),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),
        leading: MiniappIcon(
          path: item.entry.iconPath,
          asset: item.entry.iconAsset,
        ),
        title: Text(
          item.entry.title,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          [
            if (item.entry.description.isNotEmpty) item.entry.description,
            item.entry.publisher,
          ].join('\n'),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: _opening == null ? () => _open(item) : null,
        trailing: Builder(
          builder: (anchor) => IconButton(
            tooltip: '更多',
            icon: Icon(
              Icons.more_horiz_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onPressed: () => _menu(anchor, item),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => _loading && _items.isEmpty
      ? const SingleChildScrollView(
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.all(20),
          child: SearchSkeleton(label: '正在加载收藏小程序', avatarSize: 40, rowGap: 40),
        )
      : AnimatedEntryList(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.paddingOf(context).bottom + 24,
          ),
          empty: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '还没有收藏的小程序',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          children: [
            for (final item in _items) _tile(item),
            if (_loading || _failed || _more)
              Padding(
                key: const ValueKey('footer'),
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: _loading
                      ? const CircularProgressIndicator()
                      : TextButton(
                          onPressed: _load,
                          child: Text(_failed ? '重试' : '加载更多'),
                        ),
                ),
              ),
          ],
        );
}
