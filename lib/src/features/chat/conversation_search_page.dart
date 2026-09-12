import 'dart:async';

import 'package:flutter/material.dart';

import '../../storage/conversation_reader.dart';

import 'chat_controller.dart';
import 'conversations_sheet.dart';
import 'settings_page.dart';
import 'glass_surface.dart';
import 'pagination_listener.dart';
import 'sidebar_action_icon.dart';
import 'search_aurora_background.dart';
import 'search_result_tile.dart';

class ConversationSearchPage extends StatefulWidget {
  const ConversationSearchPage({
    super.key,
    required this.controller,
    required this.preparingGoal,
  });

  final ChatController controller;
  final bool Function() preparingGoal;

  @override
  State<ConversationSearchPage> createState() => _ConversationSearchPageState();
}

class _ConversationSearchPageState extends State<ConversationSearchPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _search = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  bool _searchFailed = false;
  final _results = <ConversationSearchResult>[];
  Timer? _debounce;
  int _generation = 0;
  bool _loading = false;
  bool _hasMore = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _search.addListener(_scheduleSearch);
    _load(reset: true);
  }

  void _scheduleSearch() {
    _generation++;
    _debounce?.cancel();
    setState(() => _searchFailed = false);
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => _load(reset: true),
    );
  }

  Future<void> _load({bool reset = false}) async {
    if (!reset &&
        (_loading || !_hasMore || _query != _search.text.trim().toLowerCase()))
      return;
    final generation = _generation;
    final query = _search.text.trim().toLowerCase();
    setState(() {
      _loading = true;
      _searchFailed = false;
    });
    if (reset && _scroll.hasClients) _scroll.jumpTo(0);
    try {
      final page = await widget.controller.searchConversations(
        query,
        reset ? 0 : _results.length,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        if (reset) _results.clear();
        _results.addAll(page);
        _query = query;
        _hasMore = page.length == ConversationReader.pageSize;
      });
    } on Object {
      if (mounted && generation == _generation) {
        setState(() => _searchFailed = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('搜索失败，请重试'),
            action: SnackBarAction(
              label: '重试',
              onPressed: () => _load(reset: reset),
            ),
          ),
        );
      }
    } finally {
      if (mounted && generation == _generation)
        setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.removeListener(_scheduleSearch);
    _search.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _clear() {
    setState(_search.clear);
    _focus.requestFocus();
  }

  TextSpan _highlight(String text) {
    if (_query.isEmpty) return TextSpan(text: text);
    final matches = RegExp(
      RegExp.escape(_query),
      caseSensitive: false,
      unicode: true,
    ).allMatches(text);
    final spans = <TextSpan>[];
    var start = 0;
    for (final match in matches) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: TextStyle(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      start = match.end;
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
    return TextSpan(children: spans);
  }

  void _submit() {
    _debounce?.cancel();
    _generation++;
    _focus.unfocus();
    _load(reset: true);
  }

  void _openDrawer() {
    _focus.unfocus();
    _scaffoldKey.currentState!.openDrawer();
  }

  void _chooseConversationAction(ConversationSelection selection) {
    _scaffoldKey.currentState!.closeDrawer();
    switch (selection.action) {
      case ConversationAction.search:
        _focus.requestFocus();
      case ConversationAction.settings:
        Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => SettingsPage(
              controller: widget.controller,
              preparingGoal: widget.preparingGoal,
            ),
          ),
        );
      case ConversationAction.create:
      case ConversationAction.select:
        Navigator.pop(context, selection);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final pending = _loading || (!_searchFailed && query != _query);
    final results = query == _query ? _results : <ConversationSearchResult>[];
    final media = MediaQuery.of(context);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      key: _scaffoldKey,
      drawer: ConversationsDrawer(
        controller: widget.controller,
        onChoose: _chooseConversationAction,
      ),
      drawerEnableOpenDragGesture: !widget.controller.addingImages,
      drawerEdgeDragWidth: media.size.width,
      onDrawerChanged: (opened) {
        if (opened) _focus.unfocus();
      },
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        forceMaterialTransparency: true,
        toolbarHeight: 76,
        titleSpacing: 18,
        title: Align(
          alignment: Alignment.centerLeft,
          child: GlassSurface(
            radius: 28,
            child: RoundAction(
              icon: Icons.menu_rounded,
              label: '会话菜单',
              onPressed: _openDrawer,
            ),
          ),
        ),
      ),
      extendBody: true,
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: GlassSurface(
                        radius: 28,
                        dark: Theme.of(context).brightness == Brightness.dark,
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Stack(
                            children: [
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 48,
                                ),
                                child: TextField(
                                  controller: _search,
                                  focusNode: _focus,
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: (_) => _submit(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium!
                                      .copyWith(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w400,
                                        height: 1.4,
                                        color: colors.onSurface,
                                      ),
                                  decoration: InputDecoration(
                                    hintText: '搜索会话',
                                    hintStyle: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: const EdgeInsets.fromLTRB(
                                      48,
                                      10,
                                      48,
                                      10,
                                    ),
                                  ),
                                ),
                              ),
                              const Positioned(
                                left: 0,
                                bottom: 0,
                                child: IgnorePointer(
                                  child: SizedBox.square(
                                    dimension: 48,
                                    child: Center(
                                      child: SizedBox.square(
                                        dimension: 23,
                                        child: SidebarActionIcon(
                                          type: SidebarActionIconType.search,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (_search.text.isNotEmpty)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: RoundAction(
                                    icon: Icons.cancel,
                                    iconWidget: Icon(
                                      Icons.cancel,
                                      size: 19,
                                      color: colors.onSurfaceVariant,
                                    ),
                                    compact: true,
                                    label: '清空搜索',
                                    onPressed: _clear,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GlassSurface(
                      radius: 28,
                      dark: Theme.of(context).brightness == Brightness.dark,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: RoundAction(
                          icon: Icons.close_rounded,
                          iconWidget: Icon(
                            Icons.close_rounded,
                            size: 25,
                            color: colors.onSurface,
                          ),
                          label: '关闭搜索',
                          onPressed: () => Navigator.pop(context),
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
      body: Stack(
        children: [
          const Positioned.fill(child: SearchAuroraBackground()),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: PaginationListener(
                hasMore: _hasMore,
                loadMore: () => _load(),
                child: ListView.builder(
                  controller: _scroll,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    12,
                    media.padding.top + 76 + 16,
                    12,
                    media.viewInsets.bottom + media.viewPadding.bottom + 104,
                  ),
                  itemCount: results.isEmpty ? 2 : results.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 32),
                          Text(
                            query.isEmpty ? '最近会话' : '搜索结果',
                            style: TextStyle(
                              fontSize: 30,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            query.isEmpty ? '从这里继续你的思考' : '查找会话中的相关内容',
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.5,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 48),
                        ],
                      );
                    }
                    if (results.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          _searchFailed
                              ? '输入关键词查找会话'
                              : pending
                              ? '正在搜索…'
                              : query.isEmpty
                              ? '还没有会话，开始聊天后会显示在这里'
                              : '没有找到相关会话，试试其他关键词',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      );
                    }
                    final result = results[index - 1];
                    return SearchResultTile(
                      conversation: result.conversation,
                      title: _highlight(result.conversation.title),
                      subtitle: result.snippet.isEmpty
                          ? null
                          : _highlight(result.snippet),
                      onTap: () => Navigator.pop(context, (
                        action: ConversationAction.select,
                        id: result.conversation.id,
                      )),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
