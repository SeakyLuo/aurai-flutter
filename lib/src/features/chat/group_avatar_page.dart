import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../app/ui_action.dart';
import '../../domain/avatar_style.dart';
import '../../domain/message_sender.dart';
import '../../storage/group_avatar_store.dart';
import 'chat_controller.dart';
import 'attachment_action_icon.dart';
import 'conversation_menu_icon.dart';
import 'custom_avatar_page.dart';
import 'group_avatar.dart';
import 'profile_avatar_editor.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class GroupAvatarEntry extends StatefulWidget {
  const GroupAvatarEntry({
    super.key,
    required this.controller,
    required this.conversation,
    required this.canEdit,
  });
  final ChatController controller;
  final Conversation conversation;
  final bool canEdit;
  @override
  State<GroupAvatarEntry> createState() => _GroupAvatarEntryState();
}

class _GroupAvatarEntryState extends State<GroupAvatarEntry> {
  List<MessageSender> _members = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() => runUiAction(context, () async {
    final avatars = await widget.controller.groupStore.avatarMembers([
      widget.conversation.id,
    ]);
    if (mounted) setState(() => _members = avatars[widget.conversation.id]!);
  }).then((_) {});
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 12),
    minTileHeight: settingsCardHeight,
    title: const Text('群头像', style: TextStyle(fontSize: 15)),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GroupAvatar(
          groupId: widget.conversation.id,
          members: _members,
          size: 40,
        ),
        if (widget.canEdit) ...[
          const SizedBox(width: 8),
          const SettingsIcon(type: SettingsIconType.chevron),
        ],
      ],
    ),
    onTap: widget.canEdit
        ? () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => GroupAvatarPage(
                controller: widget.controller,
                conversation: widget.conversation,
                members: _members,
              ),
            ),
          )
        : null,
  );
}

class GroupAvatarPage extends StatefulWidget {
  const GroupAvatarPage({
    super.key,
    required this.controller,
    required this.conversation,
    required this.members,
  });
  final ChatController controller;
  final Conversation conversation;
  final List<MessageSender> members;
  @override
  State<GroupAvatarPage> createState() => _GroupAvatarPageState();
}

class _GroupAvatarPageState extends State<GroupAvatarPage> {
  bool _busy = false;
  AvatarStyle get _style =>
      GroupAvatarStore.styles.value[widget.conversation.id] ??
      const AvatarStyle(icon: 'group');

  Future<void> _choose(AvatarSource source) async {
    setState(() => _busy = true);
    try {
      await runUiAction(context, () async {
        AvatarStyle? selected;
        if (source == AvatarSource.custom) {
          selected = await Navigator.push<AvatarStyle>(
            context,
            MaterialPageRoute(
              builder: (_) => CustomAvatarPage(
                initial: _style,
                name: widget.conversation.title,
                database: widget.controller.groupStore.database,
              ),
            ),
          );
        } else {
          final image = await ImagePicker().pickImage(
            source: source == AvatarSource.camera
                ? ImageSource.camera
                : ImageSource.gallery,
            maxWidth: 1024,
            maxHeight: 1024,
            imageQuality: 90,
          );
          if (image == null || !mounted) return;
          final root = await getApplicationSupportDirectory();
          final directory = await Directory(
            '${root.path}/profile_avatars',
          ).create(recursive: true);
          final path =
              '${directory.path}/${DateTime.now().microsecondsSinceEpoch}.jpg';
          await File(image.path).copy(path);
          selected = AvatarStyle(
            icon: _style.icon,
            color: _style.color,
            path: path,
          );
        }
        if (selected == null || !mounted) return;
        await _save(selected);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(AvatarStyle? style) async {
    await GroupAvatarStore(
      widget.controller.groupStore,
    ).save(widget.conversation.id, style, actorId: MessageSender.localUser.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        title: '群头像',
        onBack: _busy ? null : () => Navigator.pop(context),
      ),
      body: SettingsPageBody(
        child: ListView(
          padding: settingsPagePadding(context, const EdgeInsets.all(16)),
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 28),
              child: Center(
                child: GroupAvatar(
                  groupId: widget.conversation.id,
                  members: widget.members,
                  size: 96,
                ),
              ),
            ),
            Material(
              color: settingsFieldColor(context),
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final item in const [
                    (AvatarSource.gallery, '上传图片'),
                    (AvatarSource.camera, '拍照'),
                    (AvatarSource.custom, '自定义头像'),
                  ])
                    ListTile(
                      contentPadding: settingsCardPadding,
                      minTileHeight: settingsCardHeight,
                      enabled: !_busy,
                      leading: item.$1 == AvatarSource.custom
                          ? ConversationMenuIcon(
                              type: ConversationMenuIconType.rename,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            )
                          : AttachmentActionIcon(
                              type: item.$1 == AvatarSource.gallery
                                  ? AttachmentActionIconType.gallery
                                  : AttachmentActionIconType.camera,
                            ),
                      title: Text(
                        item.$2,
                        style: const TextStyle(fontSize: 15),
                      ),
                      onTap: _busy ? null : () => _choose(item.$1),
                    ),
                ],
              ),
            ),
            if (GroupAvatarStore.styles.value.containsKey(
              widget.conversation.id,
            ))
              ListTile(
                title: const Text('使用群成员头像'),
                trailing: const SettingsIcon(type: SettingsIconType.chevron),
                onTap: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          await runUiAction(context, () => _save(null));
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
              ),
          ],
        ),
      ),
    ),
  );
}
