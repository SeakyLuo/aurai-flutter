import 'package:flutter/material.dart';

import '../app/glass_notice.dart';
import '../domain/error_message.dart';
import '../features/chat/chat_controller.dart';
import '../features/chat/header_action_menu.dart';
import '../features/chat/settings_appearance.dart';
import '../features/chat/settings_icon.dart';
import 'miniapp_detail_page.dart';
import 'miniapp_favorites.dart';
import 'miniapp_favorites_list.dart';
import 'miniapp_home_content.dart';
import 'miniapp_home_surface.dart';
import 'miniapp_launcher.dart';
import 'miniapp_library_page.dart';
import 'miniapp_library_store.dart';
import 'miniapp_recent_page.dart';

class MiniappHomePanel extends StatefulWidget {
  const MiniappHomePanel({
    super.key,
    required this.controller,
    required this.onClose,
  });
  final ChatController controller;
  final VoidCallback onClose;

  @override
  State<MiniappHomePanel> createState() => MiniappHomePanelState();
}

class MiniappHomePanelState extends State<MiniappHomePanel> {
  late final _store = widget.controller.htmlStore;
  late final _library = MiniappLibraryStore(_store.database);
  late final _favorites = MiniappFavorites(_store.database);
  List<MiniappEntry> _recent = [], _starred = [];
  bool _loading = false, _opening = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void _notice(Object error) => ScaffoldMessenger.of(context).showToast(
    SnackBar(content: Text(errorMessage(error))),
    kind: ToastKind.error,
  );

  Future<void> reload() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait<Object>([
        _library.recent(limit: 8),
        _favorites.page(offset: 0),
      ]);
      if (!mounted) return;
      final recent =
          results[0]
              as ({
                List<MiniappEntry> entries,
                bool more,
                int? time,
                String? id,
              });
      setState(() {
        _recent = recent.entries;
        _starred = (results[1] as List<MiniappFavorite>)
            .take(8)
            .map((item) => item.entry)
            .toList();
      });
    } on Object catch (error) {
      if (mounted) _notice(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(MiniappEntry entry) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await openMiniapp(context, entry, _store);
      if (mounted) await reload();
    } on Object catch (error) {
      if (mounted) _notice(error);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _page(Widget page) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
    if (mounted) await reload();
  }

  void _browse({bool search = false}) => _page(
    MiniappLibraryPage(
      controller: widget.controller,
      initiallySearching: search,
    ),
  );

  void _manage() => _page(
    Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        title: '我的小程序',
        onBack: () => Navigator.pop(context),
      ),
      body: MiniappFavoritesList(controller: widget.controller),
    ),
  );

  Future<void> _menu(BuildContext anchor, MiniappEntry entry) async {
    try {
      final starred = await _favorites.contains(entry);
      if (!anchor.mounted) return;
      final action = await showHeaderActionMenu(
        anchor,
        items: [
          (
            value: 'favorite',
            label: starred ? '取消收藏' : '收藏',
            icon: SettingsIcon(
              type: starred
                  ? SettingsIconType.starFilled
                  : SettingsIconType.star,
            ),
          ),
          (
            value: 'details',
            label: '小程序详情',
            icon: const SettingsIcon(type: SettingsIconType.info),
          ),
        ],
      );
      if (!mounted) return;
      if (action == 'details') {
        await _page(MiniappDetailPage(entry: entry, store: _store));
      } else if (action == 'favorite') {
        if (starred) {
          await _favorites.remove(entry);
        } else {
          await _favorites.add(entry);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showToast(
          SnackBar(content: Text(starred ? '已取消收藏' : '已收藏小程序')),
          kind: ToastKind.success,
        );
        await reload();
      }
    } on Object catch (error) {
      if (mounted) _notice(error);
    }
  }

  @override
  Widget build(BuildContext context) => MiniappHomeSurface(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        title: '小程序',
        root: true,
        onBack: widget.onClose,
      ),
      body: MiniappHomeContent(
        recent: _recent,
        favorites: _starred,
        loading: _loading,
        opening: _opening,
        onSearch: () => _browse(search: true),
        onRecent: () => _page(MiniappRecentPage(store: _store)),
        onManage: _manage,
        onBrowse: _browse,
        onOpen: _open,
        onMenu: _menu,
      ),
    ),
  );
}
