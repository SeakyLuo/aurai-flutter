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
import '../../domain/avatar_style.dart';
import 'chat_controller.dart';
import 'ai_contact_editor.dart';
import 'ai_contact_page.dart';
import 'profile_avatar.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'pagination_listener.dart';
import 'recent_chats_page.dart';
import 'sidebar_action_icon.dart';

class AiContactsPage extends StatefulWidget {
  const AiContactsPage({
    super.key,
    required this.controller,
    this.archived = false,
    this.root = false,
    this.embedded = false,
    this.selectForConversation = false,
    this.conversationMode = ConversationMode.normal,
  });
  final ChatController controller;
  final bool archived;
  final bool root;
  final bool embedded;
  final bool selectForConversation;
  final ConversationMode conversationMode;
  @override
  State<AiContactsPage> createState() => _AiContactsPageState();
}

class _AiContactsPageState extends State<AiContactsPage> {
  final _search = TextEditingController();
  final _items = <AiProfile>[];
  Timer? _debounce;
  int _generation = 0;
  int? _count;
  bool _loading = false, _more = true;
  late bool _archived;
  @override
  void initState() {
    super.initState();
    _archived = widget.archived;
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (!reset && (_loading || !_more)) return;
    final generation = reset ? ++_generation : _generation;
    setState(() {
      _loading = true;
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
          offset: _items.length,
        ),
        reset
            ? widget.controller.groupStore.contactCount(
                query,
                archived: _archived,
              )
            : Future<int?>.value(_count),
      ).wait;
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(page);
        _count = count;
        _more = page.length == 50;
      });
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showGlassSnackBar(
          SnackBar(
            content: Text('朋友加载失败：${errorMessage(error)}'),
            action: SnackBarAction(
              label: '重试',
              onPressed: () => _load(reset: true),
            ),
          ),
        );
    } finally {
      if (mounted && generation == _generation)
        setState(() => _loading = false);
    }
  }

  Future<void> _open(String id) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            AiContactPage(controller: widget.controller, senderId: id),
      ),
    );
    if (mounted) _load(reset: true);
  }

  bool _openingConversation = false;

  Future<void> _startConversation(AiProfile ai) async {
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
        ScaffoldMessenger.of(context).showGlassSnackBar(
          SnackBar(content: Text('无法新建会话，请重试：${errorMessage(error)}')),
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
      if (mounted) _load(reset: true);
      return;
    }
    if (id != null) {
      setState(() => _archived = false);
      await _open(id);
    }
    if (mounted) _load(reset: true);
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
      if (mounted) _load(reset: true);
      return;
    }
    if (action == 'archive') {
      await changeAiArchive(context, widget.controller, ai);
      if (mounted) _load(reset: true);
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
      if (mounted) _load(reset: true);
    } else {
      await _open(ai.sender.id);
    }
  }

  @override
  Widget build(BuildContext context) => widget.embedded
      ? _body()
      : Scaffold(
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
              if (!_archived)
                SettingsGlassAction(
                  label: '添加朋友',
                  icon: Icons.add_rounded,
                  iconWidget: const SettingsIcon(type: SettingsIconType.add),
                  onPressed: _create,
                ),
            ],
          ),
          body: _body(),
        );

  Widget _body() => Column(
    children: [
      if (!_archived)
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: '搜索朋友',
              filled: true,
              fillColor: settingsFieldColor(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(26),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) {
              _generation++;
              _debounce?.cancel();
              _debounce = Timer(
                const Duration(milliseconds: 250),
                () => _load(reset: true),
              );
            },
          ),
        ),
      if (!_archived && !widget.selectForConversation)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 6),
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
              child: const SidebarActionIcon(type: SidebarActionIconType.group),
            ),
            title: const Text('群聊', style: TextStyle(fontSize: 16)),
            trailing: const SettingsIcon(type: SettingsIconType.chevron),
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => RecentChatsPage(
                  controller: widget.controller,
                  groupsOnly: true,
                ),
              ),
            ),
          ),
        ),
      Expanded(
        child: _archived && _loading && _items.isEmpty
            ? const SingleChildScrollView(
                physics: NeverScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: SearchSkeleton(
                  label: '正在加载归档朋友',
                  avatarSize: 44,
                  rowGap: 32,
                ),
              )
            : _items.isEmpty
            ? Center(
                child: _loading
                    ? const CircularProgressIndicator()
                    : Text(
                        _search.text.isNotEmpty
                            ? '没有找到朋友'
                            : _archived
                            ? '没有已归档朋友'
                            : '点击右上角，创建你的第一个 AI',
                      ),
              )
            : PaginationListener(
                hasMore: _more,
                loadMore: _load,
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    0,
                    12,
                    MediaQuery.paddingOf(context).bottom + 16,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final ai = _items[index];
                    return Builder(
                      builder: (anchorContext) => ListTile(
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
                        onLongPress: widget.selectForConversation
                            ? null
                            : () => _menu(ai, anchorContext),
                      ),
                    );
                  },
                ),
              ),
      ),
      if (_count != null && (!_archived || _items.isNotEmpty))
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              _archived ? '共 $_count 位已归档朋友' : '共 $_count 位朋友',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
    ],
  );
}
