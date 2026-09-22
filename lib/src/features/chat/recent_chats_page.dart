import 'animated_entry_list.dart';
import '../../app/glass_notice.dart';
import 'conversation_list_skeleton.dart';
import '../../scheduling/tasks_page.dart';
import 'settings_icon.dart';
import 'conversation_search_page.dart';
import 'conversation_list_tile.dart';
import '../../domain/error_message.dart';
import 'ai_contacts_page.dart';
import 'temporary_conversation_dialog.dart';
import 'conversation_icon.dart';
import 'header_action_menu.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/avatar_style.dart';
import '../../domain/message_sender.dart';
import '../../storage/home_conversations.dart';
import 'conversation_more.dart';
import 'chat_controller.dart';
import 'group_create_page.dart';
import 'group_avatar.dart';
import 'home_navigation.dart';
import 'pagination_listener.dart';
import 'profile_avatar.dart';
import 'settings_appearance.dart';
import 'sidebar_action_icon.dart';

class RecentChatsPage extends StatefulWidget {
  const RecentChatsPage({
    super.key,
    required this.controller,
    this.groupsOnly = false,
  });
  final ChatController controller;
  final bool groupsOnly;
  @override
  State<RecentChatsPage> createState() => RecentChatsPageState();
}

class RecentChatsPageState extends State<RecentChatsPage> {
  final _items = <Conversation>[];
  final _senders = <String, MessageSender>{};
  final _groups = <String, List<MessageSender>>{};
  Timer? _updates;
  int _groupCount = 0;
  bool _loading = false, _more = true, _loaded = false;
  @override
  void initState() {
    super.initState();
    reload();
    widget.controller.addListener(_changed);
  }

  void _changed() {
    if (!ModalRoute.of(context)!.isCurrent) return;
    if (_updates?.isActive == true) return;
    _updates = Timer(const Duration(milliseconds: 500), reload);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.isCurrentOf(context);
    if (_loaded && current == true) _changed();
  }

  @override
  void dispose() {
    _updates?.cancel();
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  Future<void> reload() => _load(reset: true);
  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final reader = HomeConversations(widget.controller.groupStore);
      late final List<Conversation> page;
      var groupCount = _groupCount;
      if (widget.groupsOnly) {
        final results = await Future.wait<Object>([
          reader.groups(after: reset || _items.isEmpty ? null : _items.last),
          reader.groupCount(),
        ]);
        page = results[0] as List<Conversation>;
        groupCount = results[1] as int;
      } else {
        page = await reader.recent(offset: reset ? 0 : _items.length);
      }
      final avatars = await Future.wait<Object>([
        reader.senders(page),
        widget.controller.groupStore.avatarMembers(
          page
              .where((item) => item.kind == ConversationKind.group)
              .map((item) => item.id)
              .toList(),
        ),
      ]);
      if (!mounted) return;
      setState(() {
        if (reset) {
          _items.clear();
          _senders.clear();
          _groups.clear();
        }
        final existing = _items.map((item) => item.id).toSet();
        _items.addAll(page.where((item) => !existing.contains(item.id)));
        _senders.addAll(avatars[0] as Map<String, MessageSender>);
        _groups.addAll(avatars[1] as Map<String, List<MessageSender>>);
        _more = page.length == HomeConversations.pageSize;
        _loaded = true;
        _groupCount = groupCount;
      });
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showGlassSnackBar(
          SnackBar(
            content: Text('会话加载失败：${errorMessage(error)}'),
            action: SnackBarAction(
              label: '重试',
              onPressed: () => _load(reset: reset),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _opening = false;
  Future<void> _temporaryConversation() async {
    final mode = await showDialog<ConversationMode>(
      context: context,
      builder: (_) => const TemporaryConversationDialog(),
    );
    if (!mounted || mode == null) return;
    await _newConversation(mode: mode);
  }

  Future<void> _newConversation({
    ConversationMode mode = ConversationMode.normal,
  }) async {
    if (_opening) return;
    _opening = true;
    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => AiContactsPage(
            controller: widget.controller,
            selectForConversation: true,
            conversationMode: mode,
          ),
        ),
      );
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showGlassSnackBar(
          SnackBar(content: Text('无法新建会话，请重试：${errorMessage(error)}')),
        );
    } finally {
      _opening = false;
    }
  }

  Future<void> _group() async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => GroupCreatePage(controller: widget.controller),
      ),
    );
    if (mounted && id != null)
      await openHomeConversation(
        context,
        widget.controller,
        id,
        resetStack: true,
      );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: SettingsAppBar(
      title: widget.groupsOnly ? '群聊' : '会话',
      gradientBackground: true,
      onBack: widget.groupsOnly ? () => Navigator.pop(context) : null,
      root: !widget.groupsOnly,
      leadingAction: widget.groupsOnly
          ? null
          : SettingsGlassAction(
              label: '搜索会话',
              icon: Icons.search_rounded,
              iconWidget: const SidebarActionIcon(
                type: SidebarActionIconType.search,
              ),
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => ConversationSearchPage(
                    controller: widget.controller,
                    preparingGoal: () => false,
                  ),
                ),
              ),
            ),
      actions: [
        if (!widget.groupsOnly)
          Builder(
            builder: (buttonContext) => SettingsGlassAction(
              label: '添加',
              icon: Icons.add_rounded,
              iconWidget: const SidebarActionIcon(
                type: SidebarActionIconType.add,
              ),
              onPressed: () async {
                final iconColor =
                    Theme.of(buttonContext).brightness == Brightness.dark
                    ? Theme.of(buttonContext).colorScheme.onSurfaceVariant
                    : const Color(0xff222222);
                final action = await showHeaderActionMenu(
                  buttonContext,
                  items: [
                    (
                      value: 'conversation',
                      label: '发起会话',
                      icon: ConversationIcon(color: iconColor),
                    ),
                    (
                      value: 'temporary',
                      label: '发起临时会话',
                      icon: ConversationIcon(temporary: true, color: iconColor),
                    ),
                    (
                      value: 'group',
                      label: '发起群聊',
                      icon: SidebarActionIcon(
                        type: SidebarActionIconType.group,
                        color: iconColor,
                      ),
                    ),
                    (
                      value: 'tasks',
                      label: '定时任务',
                      icon: SettingsIcon(
                        type: SettingsIconType.tasks,
                        color: iconColor,
                      ),
                    ),
                  ],
                );
                if (!mounted) return;
                if (action == 'conversation') {
                  await _newConversation();
                } else if (action == 'temporary') {
                  await _temporaryConversation();
                } else if (action == 'group') {
                  await _group();
                } else if (action == 'tasks') {
                  await openScheduledTasks(context, widget.controller);
                }
              },
            ),
          ),
      ],
    ),
    body: !_loaded
        ? Center(
            child: _loading
                ? const ConversationListSkeleton()
                : TextButton(onPressed: reload, child: const Text('重试加载')),
          )
        : PaginationListener(
            hasMore: _more,
            loadMore: _load,
            child: AnimatedEntryList(
              padding: EdgeInsets.fromLTRB(
                12,
                MediaQuery.paddingOf(context).top + 76 + 8,
                12,
                MediaQuery.paddingOf(context).bottom + 24,
              ),
              empty: widget.groupsOnly
                  ? const Center(child: Text('暂无群聊'))
                  : Padding(
                      padding: EdgeInsets.fromLTRB(
                        12,
                        MediaQuery.paddingOf(context).top + 84,
                        12,
                        0,
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: _roundedTile(
                          ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 0,
                            ),
                            horizontalTitleGap: 12,
                            leading: const ProfileAvatar(
                              style: AvatarStyle(icon: 'app_logo'),
                              name: 'Aurai',
                              size: 48,
                            ),
                            title: const Text('开始新会话'),
                            subtitle: const Text('选择一个 AI 开始聊天'),
                            onTap: _newConversation,
                          ),
                        ),
                      ),
                    ),
              children: [
                if (_loading && _items.isEmpty)
                  const Center(child: CircularProgressIndicator()),
                for (final item in _items)
                  ConversationMore(
                    key: ValueKey(item.id),
                    controller: widget.controller,
                    conversation: item,
                    onChanged: reload,
                    child: _tile(item),
                  ),
                if (_loading && _items.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (widget.groupsOnly && _items.isNotEmpty)
                  Padding(
                    key: const ValueKey('group-count'),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      '共 $_groupCount 个群聊',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
  );

  Widget _tile(Conversation item) {
    final group = item.kind == ConversationKind.group;
    final sender = group ? null : _senders[item.defaultSenderId]!;
    return ConversationListTile(
      controller: widget.controller,
      conversation: item,
      avatar: group
          ? GroupAvatar(members: _groups[item.id]!, size: 48)
          : ProfileAvatar(
              style: AvatarStyle(
                icon: sender!.avatarIcon,
                color: sender.avatarColor,
                path: sender.avatarPath,
              ),
              name: sender.name,
              size: 48,
            ),
      onTap: () async {
        try {
          await openHomeConversation(
            context,
            widget.controller,
            item.id,
            waitForClose: widget.groupsOnly,
          );
        } on Object catch (error) {
          if (mounted)
            ScaffoldMessenger.of(context).showGlassSnackBar(
              SnackBar(content: Text('无法打开会话，请重试：${errorMessage(error)}')),
            );
        }
        if (mounted) reload();
      },
    );
  }

  Widget _roundedTile(Widget child, {bool pinned = false}) => Material(
    color: pinned
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.035)
        : Colors.transparent,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}
