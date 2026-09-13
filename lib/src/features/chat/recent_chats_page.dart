import 'ai_contacts_page.dart';
import 'conversation_icon.dart';
import 'conversation_preview_text.dart';
import 'header_action_menu.dart';
import 'dart:async';
import 'conversation_status_dot.dart';
import 'package:flutter/material.dart';
import '../../domain/avatar_style.dart';
import '../../domain/message_sender.dart';
import '../../storage/home_conversations.dart';
import 'ai_conversations_page.dart';
import 'chat_controller.dart';
import 'group_avatar.dart';
import 'group_create_page.dart';
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
    _updates?.cancel();
    if (!ModalRoute.of(context)!.isCurrent) return;
    _updates = Timer(const Duration(milliseconds: 500), reload);
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
      final result = await Future.wait<Object>([
        reader.senders(page),
        widget.controller.groupStore.avatarMembers(
          page
              .where((c) => c.kind == ConversationKind.group)
              .map((c) => c.id)
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
        _senders.addAll(result[0] as Map<String, MessageSender>);
        _groups.addAll(result[1] as Map<String, List<MessageSender>>);
        _more = page.length == HomeConversations.pageSize;
        _loaded = true;
      });
    } on Object {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('会话加载失败'),
            action: SnackBarAction(label: '重试', onPressed: reload),
          ),
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openAi(String id) async {
    try {
      final profile = await widget.controller.groupStore.loadAi(id);
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => AiConversationsPage(
            controller: widget.controller,
            profile: profile,
          ),
        ),
      );
      if (mounted) reload();
    } on Object {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法打开会话，请重试')));
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
    appBar: SettingsAppBar(
      title: '会话',
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
                items: const [
                  (
                    value: 'conversation',
                    label: '发起会话',
                    icon: ConversationIcon(),
                  ),
                  (
                    value: 'group',
                    label: '发起群聊',
                    icon: SidebarActionIcon(type: SidebarActionIconType.group),
                  ),
                ],
              );
              if (!mounted) return;
              if (action == 'conversation') {
                await Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AiContactsPage(controller: widget.controller),
                  ),
                );
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (_loaded && _items.isEmpty)
                  _roundedTile(
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      leading: const ProfileAvatar(
                        style: AvatarStyle(icon: 'app_logo'),
                        name: 'Aurai',
                        size: 48,
                      ),
                      title: const Text('Aurai'),
                      subtitle: const Text('开始新会话'),
                      onTap: () => _openAi(MessageSender.aurai.id),
                    ),
                  ),
                for (final item in _items) _tile(item),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        leading: group
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
        title: Text(
          group ? item.title : sender!.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16),
        ),
        subtitle: ConversationPreviewText(
          conversation: item,
          emptyText: group ? '开始聊天' : item.title,
        ),
        trailing: ConversationStatusDot(conversation: item),
        onTap: () async {
          if (!group) {
            await _openAi(item.defaultSenderId);
            return;
          }
          try {
            await openHomeConversation(context, widget.controller, item.id);
          } on Object {
            if (mounted)
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('无法打开群聊，请重试')));
          }
          if (mounted) reload();
        },
      ),
    );
  }

  Widget _roundedTile(Widget child) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}
