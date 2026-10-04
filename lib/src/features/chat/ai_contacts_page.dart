import 'floating_search_layout.dart';
import 'glass_surface.dart';
import '../../widgets/empty_data_view.dart';
import 'search_skeleton.dart';
import '../../app/glass_notice.dart';
import 'header_action_menu.dart';
import '../../domain/error_message.dart';
import '../../domain/message_sender.dart';
import 'home_navigation.dart';
import 'ai_contact_actions.dart';
import 'conversation_menu_icon.dart';
import 'conversation_icon.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/ai_profile.dart';
import '../../domain/contact_name_order.dart';
import '../../domain/avatar_style.dart';
import 'chat_controller.dart';
import 'ai_contact_editor.dart';
import 'ai_contact_page.dart';
import 'profile_avatar.dart';
import 'settings_appearance.dart';
import 'menu_press_highlight.dart';
import 'settings_icon.dart';
import 'pagination_listener.dart';
import 'recent_chats_page.dart';
import 'sidebar_action_icon.dart';
import 'contact_profile_split.dart';

class AiContactsPage extends StatefulWidget {
  const AiContactsPage({
    super.key,
    required this.controller,
    this.archived = false,
    this.root = false,
    this.embedded = false,
    this.selectForConversation = false,
    this.returnSelection = false,
    this.conversationMode = ConversationMode.normal,
    this.searchController,
    this.onToggleSearch,
  });
  final ChatController controller;
  final bool archived;
  final bool root;
  final bool embedded;
  final bool selectForConversation;
  final bool returnSelection;
  final ConversationMode conversationMode;
  final TextEditingController? searchController;
  final VoidCallback? onToggleSearch;
  @override
  State<AiContactsPage> createState() => _AiContactsPageState();
}

class _AiContactsPageState extends State<AiContactsPage> {
  final _profileSplit = GlobalKey<ContactProfileSplitState>();
  late final _search = widget.searchController ?? TextEditingController();
  late String _searchQuery;
  final _items = <AiProfile>[];
  Timer? _debounce;
  int _generation = 0;
  int? _count;
  bool _loading = false, _more = true, _failed = false;
  late bool _archived;
  @override
  void initState() {
    super.initState();
    _archived = widget.archived;
    _searchQuery = _search.text;
    _search.addListener(_searchChanged);
    widget.controller.contactsChanged.addListener(_contactsChanged);
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.removeListener(_searchChanged);
    widget.controller.contactsChanged.removeListener(_contactsChanged);
    if (widget.searchController == null) _search.dispose();
    super.dispose();
  }

  void _searchChanged() {
    if (_search.text == _searchQuery) return;
    _searchQuery = _search.text;
    _generation++;
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => _load(reset: true),
    );
  }

  Future<void> _contactsChanged() async {
    final ai = widget.controller.contactsChanged.value!;
    final index = _items.indexWhere((item) => item.sender.id == ai.sender.id);
    if (index >= 0 &&
        _items[index].sender.name == ai.sender.name &&
        _items[index].sender.archived == ai.sender.archived) {
      setState(() => _items[index] = ai);
      return;
    }
    final generation = _generation;
    final query = _search.text.trim();
    try {
      final (contacts, count) = await (
        widget.controller.groupStore.contacts(
          query,
          archived: _archived,
          senderId: ai.sender.id,
        ),
        widget.controller.groupStore.contactCount(query, archived: _archived),
      ).wait;
      if (!mounted || generation != _generation) return;
      setState(() {
        final boundary = _more && _items.isNotEmpty
            ? ContactNameOrder(_items.last.sender.id, _items.last.sender.name)
            : null;
        _items.removeWhere((item) => item.sender.id == ai.sender.id);
        _items.addAll(
          contacts.where(
            (item) =>
                boundary == null ||
                ContactNameOrder(
                      item.sender.id,
                      item.sender.name,
                    ).compareTo(boundary) <=
                    0,
          ),
        );
        _items.sort(
          (a, b) => ContactNameOrder(
            a.sender.id,
            a.sender.name,
          ).compareTo(ContactNameOrder(b.sender.id, b.sender.name)),
        );
        _count = count;
        _more = _items.length < count;
      });
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showToast(
          SnackBar(content: Text('朋友更新失败：${errorMessage(error)}')),
          kind: ToastKind.error,
        );
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (!reset && (_loading || !_more)) return;
    final replace = reset;
    const limit = 50;
    final generation = replace ? ++_generation : _generation;
    setState(() {
      _loading = true;
      _failed = false;
      if (reset) {
        _items.clear();
        _count = null;
      }
    });
    try {
      final query = _search.text.trim();
      final (page, count) = await (
        widget.controller.groupStore.contacts(
          query,
          archived: _archived,
          offset: replace ? 0 : _items.length,
          limit: limit,
        ),
        replace
            ? widget.controller.groupStore.contactCount(
                query,
                archived: _archived,
              )
            : Future<int?>.value(_count),
      ).wait;
      if (!mounted || generation != _generation) return;
      setState(() {
        if (replace) _items.clear();
        _items.addAll(page);
        _count = count;
        _more = page.length == limit;
      });
    } on Object catch (error) {
      if (mounted && generation != _generation) return;
      if (mounted) setState(() => _failed = true);
      if (mounted)
        ScaffoldMessenger.of(context).showToast(
          SnackBar(content: Text('朋友加载失败：${errorMessage(error)}')),
          kind: ToastKind.error,
        );
    } finally {
      if (mounted && generation == _generation)
        setState(() => _loading = false);
    }
  }

  Future<void> _open(String id) async {
    await _openDetail(
      AiContactPage(controller: widget.controller, senderId: id),
    );
  }

  Future<void> _openDetail(Widget page) async {
    final route = MaterialPageRoute<void>(builder: (_) => page);
    if (_profileSplit.currentState!.supportsSplit) {
      await _profileSplit.currentState!.open(route);
    } else {
      await Navigator.push<void>(context, route);
    }
  }

  bool _openingConversation = false;

  Future<void> _startConversation(AiProfile ai) async {
    if (widget.returnSelection) {
      Navigator.pop(context, ai);
      return;
    }
    if (_openingConversation) return;
    _openingConversation = true;
    try {
      final id = await widget.controller.openAiConversation(
        ai,
        newConversation: true,
        mode: widget.conversationMode,
      );
      if (!mounted) return;
      await openHomeConversation(
        context,
        widget.controller,
        id,
        waitForClose: true,
        resetStack: true,
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showToast(
          SnackBar(content: Text('无法新建会话，请重试：${errorMessage(error)}')),
          kind: ToastKind.error,
        );
      }
    } finally {
      _openingConversation = false;
    }
  }

  Future<void> _create() async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(
        builder: (_) => AiContactEditor(controller: widget.controller),
      ),
    );
    if (!mounted) return;
    if (id != null && widget.selectForConversation) {
      final ai = await widget.controller.groupStore.loadAi(id);
      if (mounted) await _startConversation(ai);
      return;
    }
    if (id != null) {
      if (_archived) {
        setState(() => _archived = false);
        _load(reset: true);
      }
      await _open(id);
    }
  }

  Future<void> _menu(AiProfile ai, BuildContext anchorContext) async {
    final color = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black;
    final action = await showHeaderActionMenu(
      anchorContext,
      destructiveValues: ai.sender.archived ? const {} : const {'archive'},
      items: [
        for (final item in [
          ('open', '查看资料'),
          if (!ai.sender.archived) ('message', '发消息'),
          ('edit', '编辑'),
          if (ai.sender.id != MessageSender.aurai.id || ai.sender.archived)
            ('archive', ai.sender.archived ? '恢复朋友' : '归档朋友'),
        ])
          (
            value: item.$1,
            label: item.$2,
            icon: item.$1 == 'message'
                ? ColorFiltered(
                    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                    child: const ConversationIcon(),
                  )
                : item.$1 == 'open'
                ? SettingsIcon(
                    type: SettingsIconType.personalInfo,
                    color: color,
                  )
                : ConversationMenuIcon(
                    type: item.$1 == 'edit'
                        ? ConversationMenuIconType.rename
                        : ai.sender.archived
                        ? ConversationMenuIconType.unarchive
                        : ConversationMenuIconType.archive,
                    color: item.$1 == 'archive' && !ai.sender.archived
                        ? Theme.of(context).colorScheme.error
                        : color,
                  ),
          ),
      ],
    );
    if (!mounted || action == null) return;
    if (action == 'message') {
      await openAiChat(context, widget.controller, ai);
      return;
    }
    if (action == 'archive') {
      await changeAiArchive(context, widget.controller, ai);
      return;
    }
    if (action == 'edit') {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              AiContactEditor(controller: widget.controller, profile: ai),
        ),
      );
    } else {
      await _open(ai.sender.id);
    }
  }

  @override
  Widget build(BuildContext context) =>
      ContactProfileSplit(key: _profileSplit, child: _page());

  Widget _page() => widget.embedded
      ? _body()
      : Scaffold(
          extendBodyBehindAppBar: true,
          appBar: SettingsAppBar(
            title: widget.selectForConversation
                ? switch (widget.conversationMode) {
                    ConversationMode.normal => '选择朋友',
                    ConversationMode.temporaryPersonalized => '临时个性化 · 选择朋友',
                    ConversationMode.temporaryPlain => '临时非个性化 · 选择朋友',
                  }
                : _archived
                ? '已归档朋友'
                : '通讯录',
            root: widget.root,
            onBack: () => Navigator.pop(context),
            actions: [
              if (widget.onToggleSearch != null && !_archived)
                SettingsGlassActionSurface(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RoundAction(
                        label: '搜索朋友',
                        icon: Icons.search_rounded,
                        iconWidget: const SidebarActionIcon(
                          type: SidebarActionIconType.search,
                        ),
                        onPressed: widget.onToggleSearch,
                      ),
                      SizedBox(
                        height: 18,
                        child: VerticalDivider(
                          width: 1,
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      RoundAction(
                        label: '添加朋友',
                        icon: Icons.add_rounded,
                        iconWidget: const SettingsIcon(
                          type: SettingsIconType.add,
                        ),
                        onPressed: _create,
                      ),
                    ],
                  ),
                )
              else if (!_archived)
                SettingsGlassAction(
                  label: '添加朋友',
                  icon: Icons.add_rounded,
                  iconWidget: const SettingsIcon(type: SettingsIconType.add),
                  onPressed: _create,
                ),
            ],
          ),
          body: SettingsPageBody(child: _body()),
        );

  Widget _body() => Column(
    children: [
      Expanded(
        child: FloatingSearchLayout(
          itemCount: _items.length,
          controller: _search,
          hintText: '搜索朋友',
          enabled: !_archived && widget.onToggleSearch == null,
          bottom: 16,
          child: PaginationListener(
            hasMore: _more && !_failed,
            failed: _failed,
            onRetry: () => _load(reset: _count == null),
            loadMore: _load,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: widget.embedded ? 0 : settingsHeaderHeight(context),
                  ),
                ),
                if (!_archived && !widget.selectForConversation)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: ListTile(
                        visualDensity: const VisualDensity(vertical: -1),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 6,
                        ),
                        horizontalTitleGap: 12,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        leading: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: settingsFieldColor(context),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const SidebarActionIcon(
                            type: SidebarActionIconType.group,
                          ),
                        ),
                        title: const Text('群聊', style: TextStyle(fontSize: 16)),
                        trailing: const SettingsIcon(
                          type: SettingsIconType.chevron,
                        ),
                        onTap: () => _openDetail(
                          RecentChatsPage(
                            controller: widget.controller,
                            groupsOnly: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_items.isEmpty && _archived && !_loading)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: EmptyDataView(title: '没有已归档朋友')),
                  )
                else if (_items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                      child: _archived && _loading
                          ? const SearchSkeleton(
                              label: '正在加载归档朋友',
                              avatarSize: 44,
                              rowGap: 32,
                            )
                          : Center(
                              child: _loading
                                  ? const CircularProgressIndicator()
                                  : EmptyDataView(
                                      title: _search.text.isNotEmpty
                                          ? '没有找到朋友'
                                          : _archived
                                          ? '没有已归档朋友'
                                          : '点击右上角，创建你的第一个 AI',
                                    ),
                            ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    sliver: SliverList.builder(
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final ai = _items[index];
                        return Builder(
                          builder: (anchorContext) => MenuPressHighlight(
                            onLongPressStart: widget.selectForConversation
                                ? null
                                : (_) => _menu(ai, anchorContext),
                            borderRadius: BorderRadius.circular(22),
                            child: ListTile(
                              visualDensity: const VisualDensity(vertical: -1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 0,
                              ),
                              horizontalTitleGap: 12,
                              leading: ProfileAvatar(
                                style: AvatarStyle(
                                  icon: ai.sender.avatarIcon,
                                  color: ai.sender.avatarColor,
                                  path: ai.sender.avatarPath,
                                ),
                                name: ai.sender.name,
                                size: 44,
                              ),
                              title: Text(
                                ai.sender.name,
                                style: const TextStyle(fontSize: 16),
                              ),
                              subtitle: ai.description.isEmpty
                                  ? null
                                  : Text(
                                      ai.description,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              onTap: () => widget.selectForConversation
                                  ? _startConversation(ai)
                                  : _open(ai.sender.id),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                if (_count != null && (!_archived || _items.isNotEmpty))
                  SliverToBoxAdapter(
                    child: SafeArea(
                      top: false,
                      bottom: !widget.embedded,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 20),
                        child: Text(
                          _archived ? '共 $_count 位已归档朋友' : '共 $_count 位朋友',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (!_archived &&
                    widget.onToggleSearch == null &&
                    (_items.length >= 20 || _search.text.isNotEmpty))
                  const SliverToBoxAdapter(
                    child: SizedBox(height: FloatingSearchLayout.clearance),
                  ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
