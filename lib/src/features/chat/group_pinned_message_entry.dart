import 'settings_appearance.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../app/ui_action.dart';
import '../../storage/group_message_marks.dart';
import '../../storage/group_message_search.dart';
import 'chat_controller.dart';
import 'group_saved_message_preview.dart';
import 'settings_icon.dart';
import 'pinned_message_page.dart';
import 'pinned_message_split.dart';
import 'app_bottom_sheet.dart';

class GroupPinnedMessageEntry extends StatefulWidget {
  const GroupPinnedMessageEntry({
    super.key,
    required this.controller,
    required this.groupId,
    this.embedded = false,
  });
  final ChatController controller;
  final String groupId;
  final bool embedded;
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

  Future<void> _open(GroupMessageSearchResult message) async {
    final split = context.findAncestorStateOfType<PinnedMessageSplitState>();
    if (MediaQuery.sizeOf(context).width < 600) {
      await showAppBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: false,
        builder: (_) => PinnedMessagePage(
          controller: widget.controller,
          conversationId: widget.groupId,
          messageId: message.id,
          sheet: true,
          onLocate: split?.widget.onLocate,
          messageBuilder: split?.widget.messageBuilder,
        ),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PinnedMessagePage(
          controller: widget.controller,
          conversationId: widget.groupId,
          messageId: message.id,
          onLocate: split?.widget.onLocate,
          messageBuilder: split?.widget.messageBuilder,
        ),
      ),
    );
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
    final tile = ListTile(
      contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 12),
      minTileHeight: settingsCardHeight,
      title: const Text('置顶消息', style: TextStyle(fontSize: 15)),
      subtitle: Text(
        groupSavedMessagePreview(message),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => _open(message),
      trailing: const SettingsIcon(type: SettingsIconType.chevron),
    );
    if (widget.embedded) return tile;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xff262626)
            : Colors.white,
        borderRadius: BorderRadius.circular(26),
        clipBehavior: Clip.antiAlias,
        child: tile,
      ),
    );
  }
}
