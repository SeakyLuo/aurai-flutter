import 'animated_entry_list.dart';
import '../../app/glass_notice.dart';
import 'conversation_list_skeleton.dart';
import '../../domain/error_message.dart';
import 'conversation_preview_text.dart';
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
  bool _loaded = false;
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
        _loaded = true;
        _hasMore = page.length == ConversationReader.pageSize;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _failed = true);
      ScaffoldMessenger.of(context).showGlassSnackBar(
        SnackBar(content: Text('无法加载归档会话，请重试：${errorMessage(error)}')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        gradientBackground: true,
        title: '已归档会话',
        onBack: () => Navigator.pop(context),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: !_loaded && _loading
                ? const ConversationListSkeleton()
                : AnimatedEntryList(
                    empty: Center(
                      child: Text(
                        '暂无归档会话',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      16,
                      MediaQuery.paddingOf(context).top + 76 + 16,
                      16,
                      16,
                    ),
                    children:
                        List.generate(
                              _items.length +
                                  ((_loading || _hasMore || _failed) ? 1 : 0),
                              (index) {
                                if (index == _items.length) {
                                  if (_loading) {
                                    return const Padding(
                                      padding: EdgeInsets.all(20),
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
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
                                  child: ConversationMore(
                                    controller: widget.controller,
                                    conversation: conversation,
                                    onChanged: () => _load(reset: true),
                                    child: Material(
                                      color: settingsFieldColor(context),
                                      borderRadius: BorderRadius.circular(26),
                                      clipBehavior: Clip.antiAlias,
                                      child: ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                        leading: ConversationMenuIcon(
                                          type:
                                              ConversationMenuIconType.archive,
                                          color: colors.onSurfaceVariant,
                                        ),
                                        title: Text(
                                          conversation.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle:
                                            conversation.draftPreview != null
                                            ? ConversationPreviewText(
                                                conversation: conversation,
                                              )
                                            : conversation.preview == null
                                            ? null
                                            : ConversationPreviewText(
                                                conversation: conversation,
                                                maxLines: 2,
                                              ),
                                        onTap: () => Navigator.pop(
                                          context,
                                          conversation.id,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ).indexed
                            .map(
                              (entry) => KeyedSubtree(
                                key: ValueKey(
                                  entry.$1 == _items.length
                                      ? 'footer'
                                      : _items[entry.$1].id,
                                ),
                                child: entry.$2,
                              ),
                            )
                            .toList(),
                  ),
          ),
        ),
      ),
    );
  }
}
