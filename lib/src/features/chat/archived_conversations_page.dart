import 'package:flutter/material.dart';

import '../../storage/conversation_reader.dart';
import 'chat_controller.dart';
import 'conversation_menu_icon.dart';
import 'conversation_more.dart';
import 'settings_appearance.dart';

class ArchivedConversationsPage extends StatefulWidget {
  const ArchivedConversationsPage({super.key, required this.controller});
  final ChatController controller;

  @override
  State<ArchivedConversationsPage> createState() =>
      _ArchivedConversationsPageState();
}

class _ArchivedConversationsPageState extends State<ArchivedConversationsPage> {
  final _items = <Conversation>[];
  bool _loading = true;
  bool _failed = false;
  bool _hasMore = true;
  bool _retryReset = false;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    setState(() {
      _retryReset = reset;
      _loading = true;
      _failed = false;
    });
    try {
      final page = await widget.controller.archivedConversations(
        after: reset || _items.isEmpty ? null : _items.last,
      );
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(page);
        _hasMore = page.length == ConversationReader.pageSize;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _failed = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法加载归档会话，请重试')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: SettingsAppBar(
        title: '已归档会话',
        onBack: () => Navigator.pop(context),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: _items.isEmpty && !_loading && !_failed
                ? Text(
                    '暂无归档会话',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _items.length) {
                        if (_loading) {
                          return const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (!_hasMore && !_failed)
                          return const SizedBox.shrink();
                        return Center(
                          child: TextButton(
                            onPressed: () =>
                                _load(reset: _failed && _retryReset),
                            child: Text(_failed ? '重试' : '加载更多'),
                          ),
                        );
                      }
                      final conversation = _items[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: settingsFieldColor(context),
                          borderRadius: BorderRadius.circular(26),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: ConversationMenuIcon(
                              type: ConversationMenuIconType.archive,
                              color: colors.onSurfaceVariant,
                            ),
                            title: Text(
                              conversation.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: conversation.preview == null
                                ? null
                                : Text(
                                    conversation.preview!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            trailing: ConversationMore(
                              controller: widget.controller,
                              conversation: conversation,
                              onChanged: () => _load(reset: true),
                            ),
                            onTap: () =>
                                Navigator.pop(context, conversation.id),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
