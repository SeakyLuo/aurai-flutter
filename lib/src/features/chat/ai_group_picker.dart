import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import '../../domain/message_sender.dart';
import 'package:flutter/material.dart';
import 'chat_controller.dart';
import 'group_avatar.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'pagination_listener.dart';

class AiGroupList extends StatefulWidget {
  const AiGroupList({
    super.key,
    required this.controller,
    required this.senderId,
    this.joined = true,
    this.padding = const EdgeInsets.all(16),
    required this.onSelected,
  });
  final ChatController controller;
  final String senderId;
  final bool joined;
  final EdgeInsets padding;
  final ValueChanged<Map<String, Object?>> onSelected;
  @override
  State<AiGroupList> createState() => _AiGroupListState();
}

class _AiGroupListState extends State<AiGroupList> {
  final _groups = <Map<String, Object?>>[];
  final _avatars = <String, List<MessageSender>>{};
  bool _loading = false, _more = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading || !_more) return;
    setState(() => _loading = true);
    try {
      final rows = await widget.controller.groupStore.aiGroups(
        widget.senderId,
        joined: widget.joined,
        offset: _groups.length,
      );
      final avatars = await widget.controller.groupStore.avatarMembers([
        for (final row in rows) row['id'] as String,
      ]);
      if (mounted)
        setState(() {
          _groups.addAll(rows);
          _avatars.addAll(avatars);
          _more = rows.length == 50;
        });
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showGlassSnackBar(
          SnackBar(
            content: Text('群聊加载失败：${errorMessage(error)}'),
            action: SnackBarAction(label: '重试', onPressed: _load),
          ),
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => PaginationListener(
    hasMore: _more,
    loadMore: _load,
    child: ListView(
      padding: widget.padding,
      children: [
        if (!widget.joined)
          ListTile(
            leading: const SettingsIcon(type: SettingsIconType.add),
            title: const Text('新建群聊'),
            onTap: () async {
              try {
                final group = await widget.controller.groupStore.createGroup(
                  aiIds: [widget.senderId],
                );
                if (context.mounted)
                  widget.onSelected({
                    'id': group.id,
                    'title': group.title,
                    'created': true,
                  });
              } on Object catch (error) {
                if (context.mounted)
                  ScaffoldMessenger.of(context).showGlassSnackBar(
                    SnackBar(content: Text('创建失败，请重试：${errorMessage(error)}')),
                  );
              }
            },
          ),
        for (final group in _groups)
          ListTile(
            contentPadding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Text(group['title'] as String),
            leading: GroupAvatar(members: _avatars[group['id']]!, size: 48),
            onTap: () => widget.onSelected(group),
          ),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (!_loading && _groups.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text(widget.joined ? '尚未加入群聊' : '没有可加入的群聊')),
          ),
      ],
    ),
  );
}

class AiGroupPicker extends StatelessWidget {
  const AiGroupPicker({
    super.key,
    required this.controller,
    required this.senderId,
    this.joined = true,
  });
  final ChatController controller;
  final String senderId;
  final bool joined;
  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: SettingsAppBar(
      title: joined ? '选择群聊记忆' : '加入群聊',
      onBack: () => Navigator.pop(context),
    ),
    body: AiGroupList(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + SettingsAppBar.toolbarHeight + 16,
        16,
        MediaQuery.paddingOf(context).bottom + 16,
      ),
      controller: controller,
      senderId: senderId,
      joined: joined,
      onSelected: (group) => Navigator.pop(context, group),
    ),
  );
}
