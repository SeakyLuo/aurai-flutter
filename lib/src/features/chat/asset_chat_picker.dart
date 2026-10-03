import 'floating_search_layout.dart';
import 'conversation_list_tile.dart';
import '../../widgets/empty_data_view.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import '../../domain/message_sender.dart';
import '../../storage/home_conversations.dart';
import 'chat_controller.dart';
import 'group_avatar.dart';
import 'member_avatar.dart';
import 'settings_appearance.dart';
import 'compose_icon.dart';

class AssetChatPicker extends StatefulWidget {
  const AssetChatPicker({super.key, required this.controller});
  final ChatController controller;
  @override
  State<AssetChatPicker> createState() => _AssetChatPickerState();
}

class _AssetChatPickerState extends State<AssetChatPicker> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final _items = <Conversation>[];
  final _senders = <String, MessageSender>{};
  final _groups = <String, List<MessageSender>>{};
  bool _loading = false, _more = true, _failed = false;
  int _generation = 0;
  Timer? _debounce;
  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 240 && _more && !_loading && !_failed)
        _load();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    final generation = reset ? ++_generation : _generation;
    setState(() {
      _loading = true;
      _failed = false;
      if (reset) _items.clear();
    });
    try {
      final controller = widget.controller;
      final page = await controller.imageForwardTargets(
        _search.text.trim(),
        _items.length,
      );
      final values = await Future.wait<Object?>([
        HomeConversations(controller.groupStore).senders(page),
        controller.groupStore.avatarMembers(
          page
              .where((item) => item.kind == ConversationKind.group)
              .map((item) => item.id)
              .toList(),
        ),
      ]);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(page);
        _more = page.length == 30;
        _senders.addAll(values[0] as Map<String, MessageSender>);
        _groups.addAll(values[1] as Map<String, List<MessageSender>>);
      });
    } on Object catch (error) {
      if (mounted && generation == _generation) {
        _failed = true;
        ScaffoldMessenger.of(context).showToast(
          SnackBar(content: Text(errorMessage(error))),
          kind: ToastKind.error,
        );
      }
    } finally {
      if (mounted && generation == _generation)
        setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: SettingsAppBar(title: '选择聊天', onBack: () => Navigator.pop(context)),
    body: SettingsPageBody(
      avoidHeader: true,
      child: Column(
        children: [
          ListTile(
            leading: const ComposeIcon(),
            title: const Text('新建聊天'),
            onTap: () async {
              try {
                await widget.controller.createConversation();
                if (mounted)
                  Navigator.pop(context, widget.controller.activeConversation);
              } on Object catch (error) {
                if (mounted)
                  ScaffoldMessenger.of(context).showToast(
                    SnackBar(content: Text(errorMessage(error))),
                    kind: ToastKind.error,
                  );
              }
            },
          ),

          Expanded(
            child: FloatingSearchLayout(
              itemCount: _items.length,
              controller: _search,
              onChanged: (_) {
                ++_generation;
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 250),
                  () => _load(reset: true),
                );
              },
              hintText: '搜索聊天',
              enabled: true,
              bottom: 16,
              child: CustomScrollView(
                controller: _scroll,

                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      FloatingSearchLayout.clearance,
                    ),
                    sliver: SliverMainAxisGroup(
                      slivers: [
                        SliverList.list(
                          children: [
                            for (final item in _items)
                              ConversationListTile(
                                controller: widget.controller,
                                conversation: item,
                                avatar: item.kind == ConversationKind.group
                                    ? GroupAvatar(
                                        members: _groups[item.id]!,
                                        size: 48,
                                      )
                                    : MemberAvatar(
                                        sender: _senders[item.defaultSenderId]!,
                                        size: 48,
                                      ),
                                onTap: () => Navigator.pop(context, item),
                              ),
                            if (_loading)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(),
                                ),
                              ),

                            if (_failed || _more && !_loading)
                              Center(
                                child: TextButton(
                                  onPressed: () => _load(reset: _items.isEmpty),
                                  child: Text(_failed ? '重试' : '加载更多'),
                                ),
                              ),
                          ],
                        ),
                        if (!_loading && _items.isEmpty && !_failed)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: const EmptyDataView(title: '没有找到聊天'),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
