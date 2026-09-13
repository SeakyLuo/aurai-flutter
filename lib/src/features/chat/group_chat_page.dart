import 'conversation_preview_text.dart';
import 'group_chat_navigation.dart';
import 'group_avatar.dart';
import '../../domain/message_sender.dart';
import 'package:flutter/material.dart';

import '../../storage/conversation_reader.dart';
import 'chat_controller.dart';
import 'conversation_more.dart';
import 'conversation_status_dot.dart';
import 'group_create_page.dart';
import 'pagination_listener.dart';
import 'settings_appearance.dart';
import 'sidebar_action_icon.dart';

class GroupChatPage extends StatefulWidget {
  const GroupChatPage({super.key, required this.controller});
  final ChatController controller;
  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final _items = <Conversation>[];
  final _avatars = <String, List<MessageSender>>{};
  bool _loading = false;
  bool _hasMore = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final page = await widget.controller.groupConversations(
        after: reset || _items.isEmpty ? null : _items.last,
      );
      final avatars = await widget.controller.groupStore.avatarMembers(
        page.map((item) => item.id).toList(),
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _items.clear();
          _avatars.clear();
        }
        _avatars.addAll(avatars);
        final ids = _items.map((item) => item.id).toSet();
        _items.addAll(page.where((item) => !ids.contains(item.id)));
        _hasMore = page.length == ConversationReader.pageSize;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _failed = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('群聊加载失败，请重试'),
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

  Future<void> _create() async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => GroupCreatePage(controller: widget.controller),
      ),
    );
    if (mounted && id != null) await _open(id);
  }

  Future<void> _open(String id) async {
    await openGroupConversation(context, widget.controller, id);
    if (mounted) await _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: SettingsAppBar(
        title: '群聊',
        onBack: () => Navigator.pop(context),
        actions: [
          SettingsGlassAction(
            label: '新建群聊',
            icon: Icons.add_rounded,
            iconWidget: const SidebarActionIcon(
              type: SidebarActionIconType.add,
            ),
            onPressed: _create,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: _items.isEmpty
                ? Center(
                    child: _loading
                        ? const CircularProgressIndicator()
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SidebarActionIcon(
                                type: SidebarActionIconType.group,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _failed ? '群聊' : '还没有群聊',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              if (_failed) ...[
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: _load,
                                  child: const Text('重试'),
                                ),
                              ],
                            ],
                          ),
                  )
                : PaginationListener(
                    hasMore: _hasMore && !_failed,
                    loadMore: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: _items.length + (_loading || _failed ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _items.length && _failed) {
                          return Center(
                            child: TextButton(
                              onPressed: _load,
                              child: const Text('重试'),
                            ),
                          );
                        }
                        if (index == _items.length)
                          return const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        final item = _items[index];
                        return ConversationMore(
                          controller: widget.controller,
                          conversation: item,
                          onChanged: () => _load(reset: true),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              leading: GroupAvatar(members: _avatars[item.id]!),
                              title: Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 16),
                              ),
                              subtitle: ConversationPreviewText(
                                conversation: item,
                                emptyText: '',
                              ),
                              trailing:
                                  item.runState == ChatRunState.failed ||
                                      ConversationStatusDot.hasUnreadCompletion(
                                        item,
                                      )
                                  ? ConversationStatusDot(conversation: item)
                                  : null,
                              onTap: () => _open(item.id),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
