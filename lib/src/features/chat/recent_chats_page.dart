import 'conversation_status_dot.dart';
import '../../domain/error_message.dart';
import 'ai_contacts_page.dart';
import 'temporary_conversation_dialog.dart';
import 'message_time.dart';
import 'conversation_icon.dart';
import 'conversation_preview_text.dart';
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
    required this.onOpenMenu,
  });
  final ChatController controller;
  final VoidCallback onOpenMenu;
  @override
  State<RecentChatsPage> createState() => RecentChatsPageState();
}

class RecentChatsPageState extends State<RecentChatsPage> {
  final _items = <Conversation>[];
  final _senders = <String, MessageSender>{};
  final _groups = <String, List<MessageSender>>{};
  Timer? _updates;
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
      final page = await reader.recent(offset: reset ? 0 : _items.length);
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
        _items.addAll(page);
        _senders.addAll(avatars[0] as Map<String, MessageSender>);
        _groups.addAll(avatars[1] as Map<String, List<MessageSender>>);
        _more = page.length == HomeConversations.pageSize;
        _loaded = true;
      });
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('会话加载失败：${errorMessage(error)}'),
            action: SnackBarAction(label: '重试', onPressed: reload),
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
        ScaffoldMessenger.of(context).showSnackBar(
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
      await openHomeConversation(context, widget.controller, id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: SettingsAppBar(
      title: '会话',
      gradientBackground: true,
      onBack: null,
      root: true,
      leadingAction: SettingsGlassAction(
        label: '打开侧边栏',
        icon: Icons.menu_rounded,
        onPressed: widget.onOpenMenu,
      ),
      actions: [
        Builder(
          builder: (buttonContext) => SettingsGlassAction(
            label: '添加',
            icon: Icons.add_rounded,
            iconWidget: const SidebarActionIcon(
              type: SidebarActionIconType.add,
            ),
            onPressed: () async {
              final action = await showHeaderActionMenu(
                buttonContext,
                items: [
                  (
                    value: 'conversation',
                    label: '发起会话',
                    icon: const ConversationIcon(),
                  ),
                  (
                    value: 'temporary',
                    label: '发起临时会话',
                    icon: const ConversationIcon(temporary: true),
                  ),
                  (
                    value: 'group',
                    label: '发起群聊',
                    icon: SidebarActionIcon(
                      type: SidebarActionIconType.group,
                      color: Theme.of(
                        buttonContext,
                      ).colorScheme.onSurfaceVariant,
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
              }
            },
          ),
        ),
      ],
    ),
    body: !_loaded
        ? Center(
            child: _loading
                ? const CircularProgressIndicator()
                : TextButton(onPressed: reload, child: const Text('重试加载')),
          )
        : PaginationListener(
            hasMore: _more,
            loadMore: _load,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                12,
                MediaQuery.paddingOf(context).top + 76 + 8,
                12,
                24,
              ),
              children: [
                if (_loaded && _items.isEmpty)
                  _roundedTile(
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
                for (final item in _items)
                  ConversationMore(
                    key: ValueKey(item.id),
                    controller: widget.controller,
                    conversation: item,
                    onChanged: reload,
                    child: _tile(item),
                  ),
              ],
            ),
          ),
  );

  Widget _tile(Conversation item) {
    final group = item.kind == ConversationKind.group;
    final sender = group ? null : _senders[item.defaultSenderId]!;
    return _roundedTile(
      ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        horizontalTitleGap: 12,
        leading: ConversationUnreadAvatar(
          controller: widget.controller,
          conversation: item,
          child: group
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
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16),
              ),
            ),

            if (item.lastMessageAt != null) ...[
              const SizedBox(width: 8),
              Text(
                conversationMessageTime(item.lastMessageAt!),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        subtitle: ConversationPreviewText(
          prefix: group && item.unreadMessageCount > 0
              ? '[${item.unreadMessageCount}条] '
              : '',
          showFailure: true,
          conversation: item,
          emptyText: '开始聊天',
        ),
        onTap: () async {
          try {
            await openHomeConversation(context, widget.controller, item.id);
          } on Object catch (error) {
            if (mounted)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('无法打开会话，请重试：${errorMessage(error)}')),
              );
          }
          if (mounted) reload();
        },
      ),
      pinned: item.isPinned,
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
