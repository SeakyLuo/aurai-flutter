import 'dart:async';

import 'package:flutter/material.dart';

import '../../storage/conversation_reader.dart';

import 'chat_controller.dart';
import 'chat_page.dart';
import 'conversations_sheet.dart';
import 'settings_page.dart';
import 'group_create_page.dart';
import 'group_chat_page.dart';
import 'glass_surface.dart';
import 'pagination_listener.dart';
import 'sidebar_action_icon.dart';
import '../../storage/attachment_search.dart';
import 'search_history_store.dart';
import 'search_landing_content.dart';
import 'search_file_result_tile.dart';
import 'search_skeleton.dart';
import 'search_type_segment.dart';
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
  final _files = <AttachmentSearchResult>[];
  final _historyStore = SearchHistoryStore();
  List<String> _history = [];
  bool _filesTab = false;
  bool _filesMore = false;
  Timer? _debounce;
  int _generation = 0;
  bool _loading = false;
  bool _hasMore = false;
  String _query = '';
  String _inputQuery = '';
  String? _loadingQuery;
  bool _submitted = false;
  bool _loadingRecent = true;
  List<AttachmentSearchResult> _recentFiles = [];

  @override
  void initState() {
    super.initState();
    _search.addListener(_scheduleSearch);
    _loadHistory();
    _loadRecent();
  }

  void _scheduleSearch() {
    final query = _search.text.trim().toLowerCase();
    if (query == _inputQuery) return;
    _inputQuery = query;
    _submitted = false;
    _loading = false;
    _generation++;
    _debounce?.cancel();
    setState(() => _searchFailed = false);
    if (query.isEmpty) return;
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => _load(reset: true),
    );
  }

  Future<void> _load({bool reset = false}) async {
    if (!reset &&
        (_loading ||
            !(_filesTab ? _filesMore : _hasMore) ||
            _query != _search.text.trim().toLowerCase()))
      return;
    final generation = _generation;
    final filesTab = _filesTab;
    final query = _search.text.trim().toLowerCase();
    setState(() {
      _loading = true;
      _loadingQuery = query;
      _searchFailed = false;
    });
    if (reset && _submitted && _scroll.hasClients) _scroll.jumpTo(0);
    try {
      final pages = await Future.wait([
        if (query.isNotEmpty && (reset || !filesTab))
          widget.controller.searchConversations(
            query,
            reset ? 0 : _results.length,
          )
        else
          Future.value(<ConversationSearchResult>[]),
        if (reset || filesTab)
          widget.controller.searchAttachments(
            query,
            reset ? 0 : _files.length,
            limit: query.isEmpty ? 10 : AttachmentSearch.pageSize,
          )
        else
          Future.value(<AttachmentSearchResult>[]),
      ]);
      if (!mounted || generation != _generation) return;
      final page = pages[0] as List<ConversationSearchResult>;
      final files = pages[1] as List<AttachmentSearchResult>;
      setState(() {
        if (reset) {
          _results.clear();
          _files.clear();
        }
        _results.addAll(page);
        _files.addAll(files);
        _query = query;
        if (reset || !filesTab)
          _hasMore = page.length == ConversationReader.pageSize;
        if (reset || filesTab)
          _filesMore =
              query.isNotEmpty && files.length == AttachmentSearch.pageSize;
      });
    } on Object {
      if (mounted && generation == _generation) {
        setState(() => _searchFailed = true);
        if (_submitted)
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

  TextSpan _highlight(String text, {bool archived = false}) {
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
            color: archived
                ? (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xffbbbbbb)
                      : const Color(0xff858585))
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      start = match.end;
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
    return TextSpan(children: spans);
  }

  Future<void> _loadHistory() async {
    try {
      final values = await _historyStore.read();
      if (mounted) setState(() => _history = values);
    } on Object {
      if (mounted) _historyNotice();
    }
  }

  void _historyNotice() => ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('搜索记录保存或读取失败，请重试')));

  Future<void> _saveHistory(List<String> values) async {
    setState(() => _history = values);
    try {
      await _historyStore.save(values);
    } on Object {
      if (mounted) _historyNotice();
    }
  }

  void _rememberQuery() {
    final query = _search.text.trim();
    if (query.isEmpty) return;
    unawaited(
      _saveHistory(
        [
          query,
          ..._history.where(
            (item) => item.toLowerCase() != query.toLowerCase(),
          ),
        ].take(10).toList(),
      ),
    );
  }

  Future<void> _loadRecent() async {
    try {
      final files = await widget.controller.searchAttachments('', 0, limit: 10);
      if (mounted) setState(() => _recentFiles = files);
    } on Object {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('最近文件加载失败')));
    } finally {
      if (mounted) setState(() => _loadingRecent = false);
    }
  }

  void _submit() {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return;
    _rememberQuery();
    _debounce?.cancel();
    _focus.unfocus();
    setState(() {
      _submitted = true;
      _filesTab = false;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (_loading && _loadingQuery == query) return;
    if (_query == query && !_searchFailed) return;
    _load(reset: true);
  }

  void _openDrawer() {
    _focus.unfocus();
    _scaffoldKey.currentState!.openDrawer();
  }

  Future<void> _chooseConversationAction(
    ConversationSelection selection,
  ) async {
    if (selection.action == ConversationAction.createGroup ||
        selection.action == ConversationAction.groups) {
      final id = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => selection.action == ConversationAction.createGroup
              ? GroupCreatePage(controller: widget.controller)
              : GroupChatPage(controller: widget.controller),
        ),
      );
      if (!mounted || id == null) return;
      // Remove the drawer's local history before returning the search route.
      if (_scaffoldKey.currentState!.isDrawerOpen) Navigator.pop(context);
      Navigator.pop(context, (
        action: ConversationAction.select,
        id: id,
        messageId: null,
      ));
      return;
    }
    _scaffoldKey.currentState!.closeDrawer();
    switch (selection.action) {
      case ConversationAction.search:
        _focus.requestFocus();
      case ConversationAction.settings:
        final id = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (_) => SettingsPage(
              controller: widget.controller,
              preparingGoal: widget.preparingGoal,
            ),
          ),
        );
        if (mounted && id != null) {
          Navigator.pop(context, (
            action: ConversationAction.select,
            id: id,
            messageId: null,
          ));
        }
      case ConversationAction.groups:
      case ConversationAction.createGroup:
      case ConversationAction.tasks:
      case ConversationAction.create:
      case ConversationAction.select:
        Navigator.pop(context, selection);
    }
  }

  Future<void> _openSearchConversation(String id, String? messageId) async {
    _rememberQuery();
    _focus.unfocus();
    try {
      await widget.controller.selectConversation(id);
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            controller: widget.controller,
            fromTask: true,
            initialMessageId: messageId,
          ),
        ),
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法打开会话，请重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _submitted ? _search.text.trim().toLowerCase() : '';
    final pending = _submitted
        ? _loading || (!_searchFailed && query != _query)
        : _loadingRecent;
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
      drawerEdgeDragWidth: 24,
      onDrawerChanged: (opened) {
        if (opened) _focus.unfocus();
      },
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        forceMaterialTransparency: true,
        toolbarHeight: 64,
        leadingWidth: 74,
        leading: Padding(
          padding: const EdgeInsets.only(left: 18),
          child: Align(
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
        centerTitle: true,
        titleSpacing: 0,
        actions: const [SizedBox(width: 74)],
        title: query.isEmpty
            ? null
            : SearchTypeSegment(
                files: _filesTab,
                onChanged: (files) {
                  setState(() => _filesTab = files);
                  if (_scroll.hasClients) _scroll.jumpTo(0);
                },
              ),
      ),
      extendBody: true,
      resizeToAvoidBottomInset: false,
      backgroundColor: colors.surface,
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
                                    hintText: '搜索会话和文件',
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
                                      16,
                                      10,
                                      48,
                                      10,
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
                          iconWidget: _search.text.trim().isNotEmpty
                              ? SidebarActionIcon(
                                  type: SidebarActionIconType.search,
                                  color: colors.onSurface,
                                )
                              : Icon(
                                  Icons.close_rounded,
                                  size: 25,
                                  color: colors.onSurface,
                                ),
                          label: _search.text.trim().isNotEmpty ? '搜索' : '关闭搜索',
                          onPressed: _search.text.trim().isNotEmpty
                              ? _submit
                              : () => Navigator.pop(context),
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              SizedBox(height: media.padding.top + 64),
              Expanded(
                child:
                    query.isNotEmpty &&
                        _filesTab &&
                        !pending &&
                        !_searchFailed &&
                        _files.isEmpty
                    ? Padding(
                        padding: EdgeInsets.only(
                          bottom:
                              media.viewInsets.bottom +
                              media.viewPadding.bottom +
                              104,
                        ),
                        child: Center(
                          child: Text(
                            '没有找到相关文件',
                            style: TextStyle(
                              fontSize: 14,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    : PaginationListener(
                        hasMore:
                            query.isNotEmpty &&
                            (_filesTab ? _filesMore : _hasMore),
                        loadMore: () => _load(),
                        child: ListView.builder(
                          controller: _scroll,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.fromLTRB(
                            16,
                            4,
                            16,
                            media.viewInsets.bottom +
                                media.viewPadding.bottom +
                                104,
                          ),
                          itemCount: query.isEmpty
                              ? 1
                              : (_filesTab
                                        ? (query == _query ? _files.length : 0)
                                        : results.length) +
                                    1,
                          itemBuilder: (context, index) {
                            final empty = query.isEmpty
                                ? _recentFiles.isEmpty
                                : (_filesTab
                                      ? _files.isEmpty
                                      : results.isEmpty);
                            if (pending && (query != _query || empty)) {
                              return index == 0
                                  ? const SearchSkeleton()
                                  : const SizedBox.shrink();
                            }
                            if (query.isEmpty)
                              return SearchLandingContent(
                                files: _recentFiles,
                                history: _history,
                                onSearch: (value) {
                                  _search.text = value;
                                  _submit();
                                },
                                onRemove: (value) => _saveHistory(
                                  _history
                                      .where((item) => item != value)
                                      .toList(),
                                ),
                                onClear: () => _saveHistory([]),
                              );
                            final count = _filesTab
                                ? (query == _query ? _files.length : 0)
                                : results.length;
                            if (index == count)
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
                                child: Text(
                                  pending
                                      ? '正在搜索…'
                                      : count == 0 && !_searchFailed
                                      ? (_filesTab ? '没有找到相关文件' : '没有找到相关会话')
                                      : '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              );
                            if (_filesTab) {
                              final file = _files[index];
                              return SearchFileResultTile(
                                result: file,
                                title: _highlight(file.fileName),
                                subtitle: _highlight(file.messageExcerpt),
                                onTap: () => _openSearchConversation(
                                  file.conversationId,
                                  file.messageId,
                                ),
                              );
                            }
                            final result = results[index];
                            return SearchResultTile(
                              plain: true,
                              conversation: result.conversation,
                              title: _highlight(
                                result.conversation.title,
                                archived: result.conversation.isArchived,
                              ),
                              subtitle: result.snippet.isEmpty
                                  ? null
                                  : TextSpan(
                                      children: [
                                        if (result.sender != null)
                                          TextSpan(
                                            text: '${result.sender!.name}：',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        _highlight(
                                          result.snippet,
                                          archived:
                                              result.conversation.isArchived,
                                        ),
                                      ],
                                    ),
                              onTap: () => _openSearchConversation(
                                result.conversation.id,
                                result.messageId,
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
