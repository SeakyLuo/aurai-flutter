import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/error_message.dart';
import '../../storage/group_message_search.dart';
import 'chat_controller.dart';
import 'group_search_type_segment.dart';
import 'home_navigation.dart';
import 'group_search_results.dart';
import 'package:path_provider/path_provider.dart';
import 'search_skeleton.dart';
import 'settings_appearance.dart';
import 'question_icon.dart';

class GroupMessageSearchPage extends StatefulWidget {
  const GroupMessageSearchPage({
    super.key,
    required this.controller,
    required this.conversationId,
  });
  final ChatController controller;
  final String conversationId;
  @override
  State<GroupMessageSearchPage> createState() => _GroupMessageSearchPageState();
}

class _GroupMessageSearchPageState extends State<GroupMessageSearchPage> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _pages = {
    for (final type in GroupSearchType.values) type: _SearchPageState(),
  };
  GroupSearchType _type = GroupSearchType.all;
  Timer? _debounce;
  int _generation = 0;
  String _query = '';
  late final Future<GroupMessageSearch> _store;
  _SearchPageState get _page => _pages[_type]!;
  bool get _awaitingQuery => _type == GroupSearchType.all && _query.isEmpty;

  @override
  void initState() {
    super.initState();
    _store = getApplicationSupportDirectory().then(
      (root) => GroupMessageSearch(
        widget.controller.groupStore.database,
        '${root.path}/message_images',
      ),
    );
    for (final entry in _pages.entries) {
      entry.value.scroll.addListener(() {
        if (entry.key == _type &&
            entry.value.loaded &&
            entry.value.scroll.position.extentAfter < 240 &&
            !entry.value.loading &&
            entry.value.more &&
            !entry.value.failed)
          _load();
      });
    }
  }

  void _changed(String value) {
    _debounce?.cancel();
    _generation++;
    setState(() {
      _query = value.trim();
      for (final page in _pages.values) page.reset();
      _page.loading = !_awaitingQuery;
    });
    if (_awaitingQuery) return;
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _page.loading = false;
      _load();
    });
  }

  Future<void> _load() async {
    if (_awaitingQuery) return;
    final type = _type;
    final page = _page;
    if (page.loading) return;
    final generation = _generation;
    final query = _query;
    setState(() {
      page.loading = true;
      page.failed = false;
    });
    try {
      final store = await _store;
      final rows = await store.search(
        widget.conversationId,
        query,
        type,
        page.results.length,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        page.results.addAll(rows);
        page.loaded = true;
        page.more = rows.length == GroupMessageSearch.pageSize;
      });
    } on Object catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() => page.failed = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('搜索失败：${errorMessage(error)}'),
          action: SnackBarAction(
            label: '重试',
            onPressed: () {
              setState(() => _type = type);
              _load();
            },
          ),
        ),
      );
    } finally {
      if (mounted && generation == _generation)
        setState(() => page.loading = false);
    }
  }

  void _select(GroupSearchType type) {
    if (type == _type) return;
    final pendingInput = _debounce?.isActive == true;
    _debounce?.cancel();
    if (pendingInput) _page.loading = false;
    setState(() => _type = type);
    if (!_page.loaded && !_page.loading) _load();
  }

  Future<void> _open(GroupMessageSearchResult result) async {
    _focus.unfocus();
    try {
      await openHomeConversation(
        context,
        widget.controller,
        widget.conversationId,
        messageId: result.id,
        preservePreviousRoute: true,
      );
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法定位消息：${errorMessage(error)}')),
        );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _input.dispose();
    _focus.dispose();
    for (final page in _pages.values) page.scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SettingsAppBar(
        title: '查找聊天记录',
        onBack: () => Navigator.pop(context),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _input,
                focusNode: _focus,
                onChanged: _changed,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) {
                  final pending = _debounce?.isActive == true;
                  _debounce?.cancel();
                  _focus.unfocus();
                  if (pending) {
                    _page.loading = false;
                    _load();
                  }
                },
                decoration: InputDecoration(
                  hintText: '搜索群消息和文件名',
                  filled: true,
                  fillColor: settingsFieldColor(context),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: _input.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '清空',
                          onPressed: () {
                            _input.clear();
                            _changed('');
                            _focus.requestFocus();
                          },
                          icon: const QuestionIcon(
                            type: QuestionIconType.close,
                          ),
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GroupSearchTypeSegment(value: _type, onChanged: _select),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: IndexedStack(
                index: _type.index,
                children: [
                  for (final type in GroupSearchType.values)
                    TickerMode(
                      enabled: type == _type,
                      child:
                          type == _type ||
                              _pages[type]!.loaded ||
                              _pages[type]!.loading
                          ? _results(context, type)
                          : const SizedBox.expand(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _results(BuildContext context, GroupSearchType type) {
    final page = _pages[type]!;
    final colors = Theme.of(context).colorScheme;
    return (type == GroupSearchType.all && _query.isEmpty)
        ? const SizedBox.expand()
        : page.loading && page.results.isEmpty
        ? const SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: SearchSkeleton(),
          )
        : page.results.isEmpty
        ? Center(
            child: page.failed
                ? TextButton(onPressed: _load, child: const Text('重新搜索'))
                : Text(
                    _query.isEmpty
                        ? '暂无${type == GroupSearchType.all ? '聊天记录' : type.label + '消息'}'
                        : '没有找到相关${type == GroupSearchType.all ? '消息' : type.label}',
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
          )
        : GroupSearchResults(
            key: PageStorageKey('${type.name}:$_query'),
            results: page.results,
            conversationId: widget.conversationId,
            htmlGames: widget.controller.htmlGames,
            type: type,
            query: _query,
            scroll: page.scroll,
            loading: page.loading,
            onLocate: _open,
          );
  }
}

class _SearchPageState {
  final scroll = ScrollController();
  final results = <GroupMessageSearchResult>[];
  bool loading = false, loaded = false, more = true, failed = false;
  void reset() {
    loaded = false;
    if (scroll.hasClients) scroll.jumpTo(0);
    results.clear();
    loading = false;
    more = true;
    failed = false;
  }
}
