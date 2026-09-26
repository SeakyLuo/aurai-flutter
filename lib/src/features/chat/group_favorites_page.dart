import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../app/ui_action.dart';
import '../../app/global_ui.dart';
import '../../domain/message_sender.dart';
import 'ai_contact_page.dart';
import 'personal_info_page.dart';
import '../../storage/group_message_marks.dart';
import '../../storage/group_message_search.dart';
import 'animated_entry_list.dart';
import 'chat_controller.dart';
import 'conversation_menu_icon.dart';
import 'home_navigation.dart';
import 'search_skeleton.dart';
import 'settings_appearance.dart';
import 'starred_message_tile.dart';

class GroupFavoritesPage extends StatefulWidget {
  const GroupFavoritesPage({
    super.key,
    required this.controller,
    required this.groupId,
    required this.groupTitle,
  });
  final ChatController controller;
  final String groupId;
  final String groupTitle;
  @override
  State<GroupFavoritesPage> createState() => _GroupFavoritesPageState();
}

class _GroupFavoritesPageState extends State<GroupFavoritesPage> {
  final _scroll = ScrollController();
  late final _store = GroupMessageMarks(widget.controller.groupStore);
  late final _renderer = getApplicationSupportDirectory().then(
    (root) =>
        GroupMessageSearch(_store.database, '${root.path}/message_images'),
  );
  final _rows = <GroupMessageSearchResult>[];
  final _markers = <String, ({String? id, String? name, DateTime savedAt})>{};
  late final StreamSubscription<String> _changes;
  bool _loading = false, _more = true, _failed = false, _reloadPending = false;

  @override
  void initState() {
    super.initState();
    _changes = GroupMessageMarks.changes.stream.listen((id) {
      if (id != widget.groupId) return;
      if (_loading) {
        _reloadPending = true;
      } else {
        _load(reset: true);
      }
    });
    _scroll.addListener(_onScroll);
    _load();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 300 && !_failed) _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading || (!reset && !_more)) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    final success = await runUiAction(context, () async {
      final rows = await _store.page(widget.groupId, reset ? 0 : _rows.length);
      final messages = await (await _renderer).hydrate(rows);
      if (!mounted) return;
      setState(() {
        if (reset) {
          _rows.clear();
          _markers.clear();
        }
        _rows.addAll(messages);
        for (final row in rows) {
          _markers[row['id'] as String] = (
            id: row['marked_by'] as String?,
            name: row['marked_by_name'] as String?,
            savedAt: DateTime.fromMicrosecondsSinceEpoch(
              row['saved_at'] as int,
            ),
          );
        }
        _more = rows.length == 40;
      });
    });
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failed = !success;
    });
    if (_reloadPending) {
      _reloadPending = false;
      await _load(reset: true);
    }
  }

  Future<void> _open(GroupMessageSearchResult message) async {
    await runUiAction(
      context,
      () => openHomeConversation(
        context,
        widget.controller,
        widget.groupId,
        messageId: message.id,
        waitForClose: true,
      ),
    );
    if (mounted) await _load(reset: true);
  }

  Widget _markerLabel(String messageId) {
    final marker = _markers[messageId]!;
    final style = TextStyle(
      fontSize: 12,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    if (marker.id == null || marker.name == null)
      return Text('已标记', style: style);
    return DefaultTextStyle(
      style: style,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('由 '),
          InkWell(
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => marker.id == MessageSender.localUser.id
                    ? PersonalInfoPage(memory: widget.controller.memory)
                    : AiContactPage(
                        controller: widget.controller,
                        senderId: marker.id!,
                        groupId: widget.groupId,
                      ),
              ),
            ),
            child: Text(
              marker.name!,
              style: TextStyle(color: GlobalUI.highlightTextColor(context)),
            ),
          ),
          const Text(' 标记'),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _changes.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        title: '群标记',
        onBack: () => Navigator.pop(context),
      ),
      body: SettingsPageBody(
        child: _loading && _rows.isEmpty
            ? SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                padding: settingsPagePadding(context, const EdgeInsets.all(16)),
                child: const SearchSkeleton(
                  label: '正在加载标记消息',
                  avatarSize: 32,
                  contentHeight: 96,
                  rowCount: 4,
                  rowGap: 28,
                ),
              )
            : AnimatedEntryList(
                controller: _scroll,
                empty: Center(
                  child: Text(
                    '还没有标记的消息',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                padding: EdgeInsets.fromLTRB(
                  0,
                  settingsHeaderHeight(context) + 16,
                  0,
                  MediaQuery.paddingOf(context).bottom + 24,
                ),
                children:
                    List.generate(
                          _rows.length +
                              ((_loading || _failed || _more) ? 1 : 0),
                          (index) {
                            if (index == _rows.length) {
                              if (_loading)
                                return const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              if (_failed || _more)
                                return Center(
                                  child: TextButton(
                                    onPressed: () => _load(),
                                    child: Text(_failed ? '重试' : '加载更多'),
                                  ),
                                );
                              return const SizedBox.shrink();
                            }
                            final message = _rows[index];
                            return StarredMessageTile(
                              key: ValueKey(message.id),
                              result: message,
                              starredAt: _markers[message.id]!.savedAt,
                              conversationId: widget.groupId,
                              conversationTitle: '',
                              sourceLabel: _markerLabel(message.id),
                              controller: widget.controller,
                              onLocate: () => _open(message),
                              onRemove: () async => runUiAction(
                                context,
                                () => _store.favorite(
                                  widget.groupId,
                                  message.id,
                                  false,
                                ),
                              ),
                              removeMenuIconType:
                                  ConversationMenuIconType.unmark,
                              removeMenuLabel: '取消群标记',
                              backLabel: '返回群标记',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            );
                          },
                        ).indexed
                        .map(
                          (entry) => KeyedSubtree(
                            key: ValueKey(
                              entry.$1 == _rows.length
                                  ? 'footer'
                                  : _rows[entry.$1].id,
                            ),
                            child: entry.$2,
                          ),
                        )
                        .toList(),
              ),
      ),
    );
  }
}
