import 'retained_tab_view.dart';
import 'animated_entry_list.dart';
import '../../app/glass_notice.dart';
import 'search_skeleton.dart';
import 'ai_contacts_page.dart';
import 'search_type_segment.dart';
import '../../domain/error_message.dart';
import 'conversation_list_tile.dart';
import 'package:flutter/material.dart';

import '../../storage/conversation_reader.dart';
import 'chat_controller.dart';
import '../../domain/avatar_style.dart';
import '../../domain/message_sender.dart';
import '../../storage/home_conversations.dart';
import 'group_avatar.dart';
import 'profile_avatar.dart';
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
  final _senders = <String, MessageSender>{};
  final _groups = <String, List<MessageSender>>{};
  bool _friends = false;
  bool _friendsOpened = false;
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
      final avatars = await Future.wait<Object>([
        HomeConversations(widget.controller.groupStore).senders(page),
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

  Widget _avatar(Conversation conversation) {
    if (conversation.kind == ConversationKind.group) {
      return GroupAvatar(members: _groups[conversation.id]!, size: 48);
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        gradientBackground: true,
        title: '已归档',
        titleWidget: SearchTypeSegment(
          files: _friends,
          labels: const ['会话', '朋友'],
          onChanged: (value) => setState(() {
            _friends = value;
            if (value) _friendsOpened = true;
          }),
        ),
        onBack: () => Navigator.pop(context),
      ),
      body: RetainedTabView(
        index: _friends ? 1 : 0,
        onChanged: (index) => setState(() {
          _friends = index == 1;
          _friendsOpened |= _friends;
        }),
        children: [
          SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: AnimatedEntryList(
                  empty: Padding(
                    padding: EdgeInsets.only(
                      top: MediaQuery.paddingOf(context).top + 76,
                    ),
                    child: Center(
                      child: Text(
                        '没有已归档会话',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    12,
                    MediaQuery.paddingOf(context).top + 76 + 8,
                    12,
                    24,
                  ),
                  children: [
                    if (!_loaded && _loading)
                      const Padding(
                        key: ValueKey('loading'),
                        padding: EdgeInsets.all(8),
                        child: SearchSkeleton(
                          label: '正在加载归档会话',
                          rowGap: 32,
                          avatarSize: 48,
                        ),
                      )
                    else if (_items.isNotEmpty || _loading || _failed)
                      ...List.generate(
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
                              return ConversationMore(
                                controller: widget.controller,
                                conversation: conversation,
                                onChanged: () => _load(reset: true),
                                child: ConversationListTile(
                                  controller: widget.controller,
                                  conversation: conversation,
                                  avatar: _avatar(conversation),
                                  onTap: () =>
                                      Navigator.pop(context, conversation.id),
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
                  ],
                ),
              ),
            ),
          ),
          if (_friendsOpened)
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.paddingOf(context).top + 76,
              ),
              child: AiContactsPage(
                controller: widget.controller,
                archived: true,
                embedded: true,
              ),
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}
