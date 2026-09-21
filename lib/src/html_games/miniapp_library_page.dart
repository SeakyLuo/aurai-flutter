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
  List<MiniappEntry> _bundled = [], _apps = [];
  bool _loading = true, _more = false;
  int _generation = 0;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    final generation = ++_generation;
    final query = _search.text.trim();
    setState(() {
      _loading = true;
      if (reset) {
        _apps = [];
        _more = false;
      }
    });
    try {
      final bundled = await _store.bundled();
      final page = await _store.page(
        bundledIds: bundled.map((e) => e.id).toList(),
        after: reset ? null : _apps.last,
        query: query,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _bundled = bundled;
        _apps = reset ? page.entries : [..._apps, ...page.entries];
        _more = page.more;
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

  void _queryChanged(String value) {
    _debounce?.cancel();
    ++_generation;
    setState(() {
      _loading = true;
      _apps = [];
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
          MiniappIcon(path: entry.iconPath),
          const SizedBox(width: 10),
          Expanded(child: Text(entry.title)),
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
      onTap: () async {
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => MiniappDetailPage(
              entry: entry,
              store: widget.controller.htmlGames,
            ),
          ),
        );
        if (mounted) _load(reset: true);
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final entries = [
      ..._bundled.where((e) => e.title.toLowerCase().contains(query)),
      ..._apps,
    ];
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
                  child: _loading && _apps.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : entries.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(query.isNotEmpty ? '没有匹配的小程序' : '暂无小程序'),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          itemCount: entries.length + (_more ? 1 : 0),
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) =>
                              index < entries.length
                              ? _tile(entries[index])
                              : TextButton(
                                  onPressed: _loading
                                      ? null
                                      : () => _load(reset: false),
                                  child: Text(_loading ? '正在加载' : '加载更多'),
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
}
