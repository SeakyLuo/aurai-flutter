import 'floating_search_layout.dart';
import '../../widgets/empty_data_view.dart';
import 'retained_tab_view.dart';
import '../../app/global_ui.dart';
import '../../app/glass_notice.dart';
import 'search_filter_menu.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import '../../storage/home_conversations.dart';
import '../../domain/message_sender.dart';
import '../../domain/avatar_style.dart';
import 'group_avatar.dart';
import 'profile_avatar.dart';
import 'message_preview_text.dart';
import '../../domain/error_message.dart';
import 'home_navigation.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'chat_header_background.dart';

import '../../storage/conversation_reader.dart';

import 'chat_controller.dart';
import 'glass_surface.dart';
import 'pagination_listener.dart';
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
    this.projectId,
    this.chatsOnly = false,
  });

  final ChatController controller;
  final bool Function() preparingGoal;
  final String? projectId;
  final bool chatsOnly;

  @override
  State<ConversationSearchPage> createState() => _ConversationSearchPageState();
}

class _ConversationSearchPageState extends State<ConversationSearchPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _search = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final _filesScroll = ScrollController();
  bool _searchFailed = false;
  final _senders = <String, MessageSender>{};
  final _groups = <String, List<MessageSender>>{};
  final _results = <ConversationSearchResult>[];
  final _files = <AttachmentSearchResult>[];
  late final _historyStore = SearchHistoryStore(projectId: widget.projectId);
  List<String> _history = [];
  bool _filesTab = false;
  bool _includeReasoning = false;
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
    if (reset && _submitted) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
      if (_filesScroll.hasClients) _filesScroll.jumpTo(0);
    }
    try {
      final pages = await Future.wait([
        if (query.isNotEmpty && (reset || !filesTab))
          widget.controller.searchConversations(
            query,
            reset ? 0 : _results.length,
            includeReasoning: _includeReasoning,
            projectId: widget.projectId,
            chatsOnly: widget.chatsOnly,
          )
        else
          Future.value(<ConversationSearchResult>[]),
        if (reset || filesTab)
          widget.controller.searchAttachments(
            query,
            reset ? 0 : _files.length,
            limit: query.isEmpty ? 10 : AttachmentSearch.pageSize,
            projectId: widget.projectId,
            chatsOnly: widget.chatsOnly,
          )
        else
          Future.value(<AttachmentSearchResult>[]),
      ]);
      if (!mounted || generation != _generation) return;
      final page = pages[0] as List<ConversationSearchResult>;
      final files = pages[1] as List<AttachmentSearchResult>;
      final conversations = page.map((result) => result.conversation).toList();
      final avatars = await Future.wait<Object>([
        HomeConversations(widget.controller.groupStore).senders(conversations),
        widget.controller.groupStore.avatarMembers(
          conversations
              .where((item) => item.kind == ConversationKind.group)
              .map((item) => item.id)
              .toList(),
        ),
      ]);
      if (!mounted || generation != _generation) return;
      setState(() {
        if (reset) {
          _senders.clear();
          _groups.clear();
          _results.clear();
          _files.clear();
        }
        _senders.addAll(avatars[0] as Map<String, MessageSender>);
        _groups.addAll(avatars[1] as Map<String, List<MessageSender>>);
        _results.addAll(page);
        _files.addAll(files);
        _query = query;
        if (reset || !filesTab)
          _hasMore = page.length == ConversationReader.pageSize;
        if (reset || filesTab)
          _filesMore =
              query.isNotEmpty && files.length == AttachmentSearch.pageSize;
      });
    } on Object catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _searchFailed = true);
        if (_submitted)
          ScaffoldMessenger.of(context).showToast(
            SnackBar(content: Text('搜索失败，请重试：${errorMessage(error)}')),
            kind: ToastKind.error,
          );
      }
    } finally {
      if (mounted && generation == _generation)
        setState(() => _loading = false);
    }
  }

  Widget _avatar(Conversation conversation) {
    if (conversation.kind == ConversationKind.group) {
      return GroupAvatar(
        groupId: conversation.id,
        members: _groups[conversation.id]!,
        size: 48,
      );
    }
    final sender = _senders[conversation.defaultSenderId]!;
    return ProfileAvatar(
      style: AvatarStyle(
        icon: sender.avatarIcon,
        color: sender.avatarColor,
        path: sender.avatarPath,
      ),
      name: sender.name,
      size: 48,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.removeListener(_scheduleSearch);
    _search.dispose();
    _focus.dispose();
    _scroll.dispose();
    _filesScroll.dispose();
    super.dispose();
  }

  void _clear() {
    setState(_search.clear);
    _focus.requestFocus();
  }

  TextSpan _highlight(
    String text, {
    bool archived = false,
    bool literal = true,
  }) => MessagePreviewText.span(context, text, query: _query, literal: literal);

  Future<void> _loadHistory() async {
    try {
      final values = await _historyStore.read();
      if (mounted) setState(() => _history = values);
    } on Object catch (error) {
      if (mounted) _historyNotice(error);
    }
  }

  void _historyNotice(Object error) => ScaffoldMessenger.of(context).showToast(
    SnackBar(content: Text('搜索记录保存或读取失败：${errorMessage(error)}')),
    kind: ToastKind.error,
  );

  Future<void> _saveHistory(List<String> values) async {
    setState(() => _history = values);
    try {
      await _historyStore.save(values);
    } on Object catch (error) {
      if (mounted) _historyNotice(error);
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
      final files = await widget.controller.searchAttachments(
        '',
        0,
        limit: 10,
        projectId: widget.projectId,
        chatsOnly: widget.chatsOnly,
      );
      final available = await Future.wait(
        files.map((result) async {
          try {
            final stat = await File(
              result.image?.path ?? result.file!.path,
            ).stat();
            return stat.type == FileSystemEntityType.file && stat.size > 0;
          } on FileSystemException {
            return false;
          }
        }),
      );
      if (mounted) {
        setState(
          () => _recentFiles = [
            for (var i = 0; i < files.length; i++)
              if (available[i]) files[i],
          ],
        );
      }
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showToast(
          SnackBar(content: Text('最近文件加载失败：${errorMessage(error)}')),
          kind: ToastKind.error,
        );
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
    if (_filesScroll.hasClients) _filesScroll.jumpTo(0);
    if (_loading && _loadingQuery == query) return;
    if (_query == query && !_searchFailed) return;
    _load(reset: true);
  }

  Future<void> _openSearchConversation(String id, String? messageId) async {
    _rememberQuery();
    _focus.unfocus();
    try {
      await openHomeConversation(
        context,
        widget.controller,
        id,
        messageId: messageId,
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showToast(
          SnackBar(content: Text('无法打开会话，请重试：${errorMessage(error)}')),
          kind: ToastKind.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _submitted ? _search.text.trim().toLowerCase() : '';
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      key: _scaffoldKey,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        forceMaterialTransparency: true,
        flexibleSpace: const ChatHeaderBackground(),
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: GlobalUI.appBarHeight,
        leadingWidth: 74,
        leading: Padding(
          padding: const EdgeInsets.only(left: 18),
          child: Align(
            alignment: Alignment.centerLeft,
            child: GlassSurface(
              radius: 28,
              shadowOpacity: .55,
              child: RoundAction(
                icon: Icons.arrow_back_rounded,
                label: '返回',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
        centerTitle: true,
        titleSpacing: 0,
        title: query.isEmpty
            ? null
            : SearchTypeSegment(
                files: _filesTab,
                labels: widget.chatsOnly
                    ? const ['会话', '文件']
                    : const ['任务', '文件'],
                onChanged: (files) {
                  setState(() => _filesTab = files);
                },
              ),
      ),
      extendBody: true,
      resizeToAvoidBottomInset: true,
      backgroundColor: colors.surface,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              Expanded(
                child: FloatingSearchLayout(
                  trailingAction: widget.chatsOnly
                      ? null
                      : Builder(
                          builder: (anchor) => SettingsGlassAction(
                            label: '搜索筛选',
                            icon: Icons.filter_list_rounded,
                            iconWidget: SettingsIcon(
                              type: SettingsIconType.filter,
                              color: _includeReasoning
                                  ? GlobalUI.highlightTextColor(context)
                                  : null,
                            ),
                            onPressed: () async {
                              final box =
                                  anchor.findRenderObject()! as RenderBox;
                              await showSearchFilterMenu(
                                context,
                                anchor:
                                    box.localToGlobal(Offset.zero) & box.size,
                                includeReasoning: _includeReasoning,
                                onChanged: (include) {
                                  _debounce?.cancel();
                                  _generation++;
                                  setState(() => _includeReasoning = include);
                                  if (_search.text.trim().isNotEmpty) {
                                    unawaited(_load(reset: true));
                                  }
                                },
                              );
                            },
                          ),
                        ),
                  controller: _search,
                  focusNode: _focus,
                  hintText: widget.projectId == null
                      ? (widget.chatsOnly ? '搜索会话和文件' : '搜索任务和文件')
                      : '在项目中搜索任务和文件',
                  onSubmitted: (_) => _submit(),
                  onChanged: (value) {
                    if (value.isEmpty) _clear();
                  },
                  child: RetainedTabView(
                    index: query.isEmpty ? 0 : (_filesTab ? 1 : 0),
                    onChanged: (index) =>
                        setState(() => _filesTab = index == 1),
                    children: [
                      _resultsPage(false),
                      if (query.isNotEmpty) _resultsPage(true),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultsPage(bool filesTab) {
    final query = _submitted ? _search.text.trim().toLowerCase() : '';
    final pending = _submitted
        ? _loading || (!_searchFailed && query != _query)
        : _loadingRecent;
    final results = query == _query ? _results : <ConversationSearchResult>[];
    final media = MediaQuery.of(context);
    return query.isNotEmpty &&
            !pending &&
            !_searchFailed &&
            (filesTab ? _files.isEmpty : results.isEmpty)
        ? Padding(
            padding: EdgeInsets.only(
              bottom: media.viewPadding.bottom + FloatingSearchLayout.clearance,
            ),
            child: EmptyDataView(
              title: filesTab
                  ? '没有找到相关文件'
                  : widget.chatsOnly
                  ? '没有找到相关会话'
                  : '没有找到相关任务',
            ),
          )
        : PaginationListener(
            failed: _searchFailed,
            retryBottomInset: FloatingSearchLayout.clearance,
            onRetry: () => _load(
              reset: _query != query || !(_filesTab ? _filesMore : _hasMore),
            ),
            hasMore: query.isNotEmpty && (filesTab ? _filesMore : _hasMore),
            loadMore: () => _load(),
            child: ListView.builder(
              controller: filesTab ? _filesScroll : _scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                16,
                settingsHeaderHeight(context) + 4,
                16,
                media.viewPadding.bottom + FloatingSearchLayout.clearance,
              ),
              itemCount: query.isEmpty
                  ? 1
                  : (filesTab
                            ? (query == _query ? _files.length : 0)
                            : results.length) +
                        1,
              itemBuilder: (context, index) {
                final empty = query.isEmpty
                    ? _recentFiles.isEmpty
                    : (filesTab ? _files.isEmpty : results.isEmpty);
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
                      _history.where((item) => item != value).toList(),
                    ),
                    onClear: () => _saveHistory([]),
                  );
                final count = filesTab
                    ? (query == _query ? _files.length : 0)
                    : results.length;
                if (index == count)
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: pending
                        ? const Text('正在搜索…', textAlign: TextAlign.center)
                        : const SizedBox.shrink(),
                  );
                if (filesTab) {
                  final file = _files[index];
                  return SearchFileResultTile(
                    result: file,
                    title: _highlight(file.fileName),
                    subtitle: _highlight(file.messageExcerpt, literal: false),
                    onTap: () => _openSearchConversation(
                      file.conversationId,
                      file.messageId,
                    ),
                  );
                }
                final result = results[index];
                return SearchResultTile(
                  plain: true,
                  avatar: _avatar(result.conversation),
                  conversation: result.conversation,
                  title: _highlight(
                    result.conversation.isPersonalChat
                        ? _senders[result.conversation.defaultSenderId]!
                              .displayName
                        : result.conversation.title,
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
                              literal: false,
                              archived: result.conversation.isArchived,
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
          );
  }
}
