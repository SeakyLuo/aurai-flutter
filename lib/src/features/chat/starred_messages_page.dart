import 'retained_tab_view.dart';
import 'search_skeleton.dart';
import '../../html_games/miniapp_favorites_list.dart';
import 'search_type_segment.dart';
import 'animated_entry_list.dart';
import '../../app/glass_notice.dart';
import 'remove_favorite.dart';
import 'package:path_provider/path_provider.dart';
import '../../storage/group_message_search.dart';
import 'starred_message_tile.dart';
import 'package:flutter/material.dart';
import '../../domain/error_message.dart';
import '../../storage/starred_messages.dart';
import 'chat_controller.dart';
import 'home_navigation.dart';
import 'settings_appearance.dart';

class StarredMessagesPage extends StatefulWidget {
  const StarredMessagesPage({super.key, required this.controller});
  final ChatController controller;

  @override
  State<StarredMessagesPage> createState() => _StarredMessagesPageState();
}

class _StarredMessagesPageState extends State<StarredMessagesPage> {
  bool _miniapps = false;
  bool _miniappsOpened = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: SettingsAppBar(
      title: '收藏',
      titleWidget: SearchTypeSegment(
        files: _miniapps,
        labels: const ['消息', '小程序'],
        onChanged: (value) => setState(() {
          _miniapps = value;
          if (value) _miniappsOpened = true;
        }),
      ),
      gradientBackground: true,
      onBack: () => Navigator.maybePop(context),
    ),
    body: RetainedTabView(
      index: _miniapps ? 1 : 0,
      onChanged: (index) => setState(() {
        _miniapps = index == 1;
        _miniappsOpened |= _miniapps;
      }),
      children: [
        TickerMode(
          enabled: !_miniapps,
          child: _StarredMessageList(controller: widget.controller),
        ),
        TickerMode(
          enabled: _miniapps,
          child: _miniappsOpened
              ? MiniappFavoritesList(controller: widget.controller)
              : const SizedBox.expand(),
        ),
      ],
    ),
  );
}

class _StarredMessageList extends StatefulWidget {
  const _StarredMessageList({required this.controller});
  final ChatController controller;
  @override
  State<_StarredMessageList> createState() => _StarredMessageListState();
}

class _StarredMessageListState extends State<_StarredMessageList> {
  final _scroll = ScrollController();
  final _rows = <Map<String, Object?>>[];
  final _messages = <String, GroupMessageSearchResult>{};
  late final _renderer = getApplicationSupportDirectory().then(
    (root) =>
        GroupMessageSearch(_store.database, '${root.path}/message_images'),
  );
  final _titles = <String, String>{};
  late final _store = StarredMessages(widget.controller.groupStore.database);
  bool _loading = false, _more = true, _failed = false, _opening = false;

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

  void _notice(Object error) {
    ScaffoldMessenger.of(
      context,
    ).showGlassSnackBar(SnackBar(content: Text(errorMessage(error))));
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading || (!reset && !_more)) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final rows = await _store.page(offset: reset ? 0 : _rows.length);
      final conversationIds = rows
          .map((row) => row['conversation_id'])
          .toSet()
          .toList();
      final renderer = await _renderer;
      final related = await Future.wait<Object>([
        renderer.hydrate(rows),
        rows.isEmpty
            ? Future.value(<Map<String, Object?>>[])
            : _store.database.query(
                'conversations',
                columns: ['id', 'title'],
                where:
                    'id IN (${List.filled(conversationIds.length, '?').join(',')})',
                whereArgs: conversationIds,
              ),
      ]);
      if (!mounted) return;
      setState(() {
        if (reset) {
          _rows.clear();
          _messages.clear();
          _titles.clear();
        }
        _rows.addAll(rows);
        for (final message in related[0] as List<GroupMessageSearchResult>) {
          _messages[message.id] = message;
        }
        for (final row in related[1] as List<Map<String, Object?>>) {
          _titles[row['id'] as String] = row['title'] as String;
        }
        _more = rows.length == 50;
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

  Future<void> _open(Map<String, Object?> row) async {
    if (_opening) return;
    _opening = true;
    try {
      await openHomeConversation(
        context,
        widget.controller,
        row['conversation_id'] as String,
        messageId: row['id'] as String,
        waitForClose: true,
      );
      if (mounted) await _load(reset: true);
    } on Object catch (error) {
      if (mounted) _notice(error);
    } finally {
      _opening = false;
    }
  }

  Future<void> _remove(Map<String, Object?> row) async {
    final message = _messages[row['id']]!;
    final title = _titles[row['conversation_id']]!;
    try {
      await removeFavorite(
        context,
        _store,
        row['id'] as String,
        onRemoved: () {
          if (mounted) setState(() => _rows.remove(row));
        },
        onRestored: () {
          if (!mounted) return;
          setState(() {
            if (_rows.any((item) => item['id'] == row['id'])) return;
            final restoredAt = row['starred_at'] as int;
            final index = _rows.indexWhere((item) {
              final time = item['starred_at'] as int;
              return time < restoredAt ||
                  (time == restoredAt &&
                      (item['id'] as String).compareTo(row['id'] as String) <
                          0);
            });
            _rows.insert(index < 0 ? _rows.length : index, row);
            _messages[message.id] = message;
            _titles[row['conversation_id'] as String] = title;
          });
        },
      );
    } on Object catch (error) {
      if (mounted) _notice(error);
    }
  }

  @override
  Widget build(BuildContext context) => _loading && _rows.isEmpty
      ? const SingleChildScrollView(
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.all(16),
          child: SearchSkeleton(
            label: '正在加载收藏消息',
            avatarSize: 32,
            contentHeight: 96,
            rowCount: 4,
            rowGap: 28,
          ),
        )
      : AnimatedEntryList(
          controller: _scroll,
          empty: Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Align(
              alignment: Alignment.topCenter,
              child: Text(
                '还没有收藏\n长按聊天消息即可添加',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.paddingOf(context).bottom + 24,
          ),
          children:
              List.generate(
                    _rows.length + ((_loading || _failed || _more) ? 1 : 0),
                    (index) {
                      if (index == _rows.length) {
                        if (_loading)
                          return const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        if (_failed)
                          return Center(
                            child: TextButton(
                              onPressed: () => _load(),
                              child: const Text('重试'),
                            ),
                          );
                        if (_more)
                          return Center(
                            child: TextButton(
                              onPressed: () => _load(),
                              child: const Text('加载更多'),
                            ),
                          );
                        return const SizedBox.shrink();
                      }
                      final row = _rows[index];
                      return StarredMessageTile(
                        key: ValueKey(row['id']),
                        result: _messages[row['id']]!,
                        conversationId: row['conversation_id'] as String,
                        conversationTitle: _titles[row['conversation_id']]!,
                        controller: widget.controller,
                        onLocate: () => _open(row),
                        onRemove: () => _remove(row),
                      );
                    },
                  ).indexed
                  .map(
                    (entry) => KeyedSubtree(
                      key: ValueKey(
                        entry.$1 == _rows.length
                            ? 'footer'
                            : _rows[entry.$1]['id'],
                      ),
                      child: entry.$2,
                    ),
                  )
                  .toList(),
        );
}
