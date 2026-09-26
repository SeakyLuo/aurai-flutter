import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/ui_action.dart';
import '../../storage/group_message_marks.dart';
import '../../storage/group_message_search.dart';
import 'chat_controller.dart';
import 'conversation_menu_icon.dart';
import 'group_saved_message_preview.dart';
import 'header_action_menu.dart';
import 'home_navigation.dart';
import 'attachment_action_icon.dart';
import 'settings_icon.dart';

class GroupPinnedMessageEntry extends StatefulWidget {
  const GroupPinnedMessageEntry({
    super.key,
    required this.controller,
    required this.groupId,
  });
  final ChatController controller;
  final String groupId;
  @override
  State<GroupPinnedMessageEntry> createState() =>
      _GroupPinnedMessageEntryState();
}

class _GroupPinnedMessageEntryState extends State<GroupPinnedMessageEntry> {
  late final _store = GroupMessageMarks(widget.controller.groupStore);
  late final StreamSubscription<String> _changes;
  GroupMessageSearchResult? _message;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _changes = GroupMessageMarks.changes.stream.listen((id) {
      if (id == widget.groupId) _load();
    });
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    await runUiAction(context, () async {
      final row = await _store.pinned(widget.groupId);
      final root = await getApplicationSupportDirectory();
      final messages = await GroupMessageSearch(
        _store.database,
        '${root.path}/message_images',
      ).hydrate([if (row != null) row]);
      if (mounted && request == _request)
        setState(() => _message = messages.firstOrNull);
    });
  }

  Future<void> _menu(
    BuildContext anchor,
    GroupMessageSearchResult message,
  ) async {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    final result = await showHeaderActionMenu(
      anchor,
      items: [
        (
          value: 'locate',
          label: '查看原消息',
          icon: AttachmentActionIcon(
            type: AttachmentActionIconType.locate,
            color: color,
          ),
        ),
        (
          value: 'show',
          label: '在聊天顶部显示',
          icon: SettingsIcon(type: SettingsIconType.eye, color: color),
        ),
        (
          value: 'unpin',
          label: '取消置顶',
          icon: ConversationMenuIcon(
            type: ConversationMenuIconType.removeTop,
            color: color,
          ),
        ),
      ],
    );
    if (!mounted || result == null) return;
    await runUiAction(context, () async {
      if (result == 'locate') {
        await openHomeConversation(
          context,
          widget.controller,
          widget.groupId,
          messageId: message.id,
          waitForClose: true,
        );
      } else if (result == 'unpin') {
        await _store.pin(widget.groupId, message.id, false);
      } else {
        await SharedPreferencesAsync().remove(
          'groupPinDismissed:${widget.groupId}',
        );
        GroupMessageMarks.changes.add(widget.groupId);
      }
    });
  }

  @override
  void dispose() {
    _changes.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = _message;
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xff262626)
            : Colors.white,
        borderRadius: BorderRadius.circular(26),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          minTileHeight: 60,
          title: const Text('置顶消息', style: TextStyle(fontSize: 15)),
          subtitle: Text(
            groupSavedMessagePreview(message),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _menu(context, message),
          trailing: const SettingsIcon(type: SettingsIconType.chevron),
        ),
      ),
    );
  }
}
