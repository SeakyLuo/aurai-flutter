import 'app_bottom_sheet.dart';
import '../../widgets/empty_data_view.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/glass_notice.dart';
import '../../domain/agent_models.dart';
import '../../domain/error_message.dart';
import '../../html_games/miniapp_favorites.dart';
import '../../html_games/miniapp_forward.dart';
import '../../html_games/miniapp_library_store.dart';
import '../../html_games/miniapp_icon.dart';
import '../../storage/group_message_search.dart';
import '../../storage/starred_messages.dart';
import 'chat_controller.dart';
import '../../storage/home_conversations.dart';
import 'image_forward_dialog.dart';
import 'group_avatar.dart';
import 'member_avatar.dart';
import 'starred_message_tile.dart';
import 'retained_tab_view.dart';
import 'search_skeleton.dart';
import 'search_type_segment.dart';
import 'settings_appearance.dart';

Future<bool?> showSendFavoritePage(
  BuildContext context,
  ChatController controller,
) => Navigator.push<bool>(
  context,
  MaterialPageRoute(
    builder: (_) => _SendFavoritePage(
      controller: controller,
      target: controller.activeConversation,
    ),
  ),
);

class _SendFavoritePage extends StatefulWidget {
  const _SendFavoritePage({required this.controller, required this.target});
  final ChatController controller;
  final Conversation target;
  @override
  State<_SendFavoritePage> createState() => _SendFavoritePageState();
}

class _SendFavoritePageState extends State<_SendFavoritePage> {
  bool _miniapps = false, _opening = false;

  void _selectTab(bool value) {
    if (_opening || _miniapps == value) return;
    setState(() => _miniapps = value);
  }

  Future<void> _select(_FavoriteChoice item) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final target = widget.target;
      final controller = widget.controller;
      final Widget avatar;
      final String recipientName;
      if (target.kind == ConversationKind.group) {
        final members = await controller.groupStore.avatarMembers([target.id]);
        avatar = GroupAvatar(
          groupId: target.id,
          members: members[target.id]!,
          size: 48,
        );
        recipientName = '群聊';
      } else {
        final senders = await HomeConversations(
          controller.groupStore,
        ).senders([target]);
        final sender = senders[target.defaultSenderId]!;
        avatar = MemberAvatar(sender: sender, size: 48);
        recipientName = sender.displayName;
      }
      if (!mounted) return;
      final message = item.message.htmlGame == null
          ? item.message
          : miniappForwardMessage(
              await MiniappLibraryStore(
                controller.htmlStore.database,
              ).entryForMessage(item.message.id),
            );
      if (!mounted) return;
      final sent = await showAppBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: false,
        enableDrag: false,
        showDragHandle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => ImageForwardDialog.message(
          controller: controller,
          message: message,
          targetId: target.id,
          kind: target.kind,
          title: target.title,
          recipientName: recipientName,
          avatar: avatar,
        ),
      );
      if (sent == true && mounted) Navigator.pop(context, true);
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showToast(
          SnackBar(content: Text(errorMessage(error))),
          kind: ToastKind.error,
        );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: SettingsAppBar(
      title: '发送收藏',
      titleWidget: SearchTypeSegment(
        files: _miniapps,
        labels: const ['消息', '小程序'],
        onChanged: _selectTab,
      ),

      onBack: () => Navigator.pop(context),
    ),
    body: SettingsPageBody(
      child: SafeArea(
        top: false,
        child: RetainedTabView(
          index: _miniapps ? 1 : 0,
          swipeEnabled: !_opening,
          onChanged: (index) => _selectTab(index == 1),
          children: [
            for (final miniapps in [false, true])
              _FavoriteChoices(
                controller: widget.controller,
                miniapps: miniapps,
                enabled: !_opening,
                onSelected: _select,
              ),
          ],
        ),
      ),
    ),
  );
}

class _FavoriteChoice {
  const _FavoriteChoice(
    this.message,
    this.title,
    this.subtitle,
    this.icon, {
    this.miniapp,
  });
  final MiniappEntry? miniapp;
  final AgentMessage message;
  final String title, subtitle;
  final Widget icon;
}

class _FavoriteChoices extends StatefulWidget {
  const _FavoriteChoices({
    required this.controller,
    required this.miniapps,
    required this.enabled,
    required this.onSelected,
  });
  final ChatController controller;
  final bool miniapps, enabled;
  final ValueChanged<_FavoriteChoice> onSelected;
  @override
  State<_FavoriteChoices> createState() => _FavoriteChoicesState();
}

class _FavoriteChoicesState extends State<_FavoriteChoices> {
  final _scroll = ScrollController();
  final _items = <_FavoriteChoice>[];
  bool _loading = false, _more = true, _failed = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 240 && !_failed) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading || !_more) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final database = widget.controller.groupStore.database;
      final choices = <_FavoriteChoice>[];
      int count;
      if (widget.miniapps) {
        final rows = await MiniappFavorites(
          database,
        ).page(offset: _items.length);
        count = rows.length;
        for (final row in rows) {
          final entry = row.entry;
          choices.add(
            _FavoriteChoice(
              miniappForwardMessage(entry),
              entry.title,
              entry.description.isEmpty ? entry.publisher : entry.description,
              MiniappIcon(
                path: entry.iconPath,
                asset: entry.iconAsset,
                size: 36,
              ),
              miniapp: entry,
            ),
          );
        }
      } else {
        final rows = await StarredMessages(
          database,
        ).page(offset: _items.length);
        count = rows.length;
        final directory = await getApplicationSupportDirectory();
        final messages = await GroupMessageSearch(
          database,
          '${directory.path}/message_images',
        ).hydrate(rows);
        for (var index = 0; index < messages.length; index++) {
          final result = messages[index];
          choices.add(
            _FavoriteChoice(
              AgentMessage(
                id: result.id,
                role: result.role,
                senderId: result.sender.id,
                sender: result.sender,
                text: result.text,
                createdAt: result.createdAt,
                images: result.images,
                miniappShare: result.miniappShare,
                files: result.files,
                htmlGame: result.html,
                interactive: result.interactive,
              ),
              result.sender.displayName,
              '',
              StarredMessageTile(
                result: result,
                starredAt: DateTime.fromMicrosecondsSinceEpoch(
                  rows[index]['starred_at'] as int,
                ),
                conversationId: rows[index]['conversation_id'] as String,
                conversationTitle: '',
                controller: widget.controller,
                onLocate: () {},
                onRemove: () {},
                selectionMode: true,
              ),
            ),
          );
        }
      }
      if (mounted)
        setState(() {
          _items.addAll(choices);
          _more = count == 50;
        });
    } on Object catch (error) {
      if (mounted) {
        _failed = true;
        ScaffoldMessenger.of(context).showToast(
          SnackBar(content: Text(errorMessage(error))),
          kind: ToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && _loading)
      return SingleChildScrollView(
        padding: settingsPagePadding(context, const EdgeInsets.all(24)),
        child: const SearchSkeleton(label: '正在加载收藏', avatarSize: 36),
      );
    if (_items.isEmpty && !_failed)
      return Center(
        child: EmptyDataView(title: widget.miniapps ? '还没有收藏的小程序' : '还没有收藏的消息'),
      );
    return ListView.builder(
      controller: _scroll,
      padding: settingsPagePadding(
        context,
        const EdgeInsets.fromLTRB(16, 16, 16, 0),
      ),
      itemCount: _items.length + ((_loading || _more || _failed) ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _items.length)
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: _loading
                  ? const CircularProgressIndicator()
                  : TextButton(
                      onPressed: _load,
                      child: Text(_failed ? '重试' : '加载更多'),
                    ),
            ),
          );
        final item = _items[index];
        if (!widget.miniapps) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.enabled ? () => widget.onSelected(item) : null,
            child: IgnorePointer(child: item.icon),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: settingsFieldColor(context),
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
              leading: item.icon,
              title: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                item.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: widget.enabled ? () => widget.onSelected(item) : null,
            ),
          ),
        );
      },
    );
  }
}
