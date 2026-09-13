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
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
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
    if (mounted && id != null) Navigator.pop(context, id);
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
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            leading: const SidebarActionIcon(
                              type: SidebarActionIconType.group,
                            ),
                            title: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 16),
                            ),
                            subtitle: Text(
                              item.preview ?? '开始群聊',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            trailing: ConversationStatusDot(conversation: item),
                            onTap: () => Navigator.pop(context, item.id),
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
