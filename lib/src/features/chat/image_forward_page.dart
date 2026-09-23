import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import '../../domain/avatar_style.dart';
import '../../domain/message_sender.dart';
import '../../storage/home_conversations.dart';
import 'group_avatar.dart';
import 'profile_avatar.dart';
import '../../domain/agent_models.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../platform/preview_image_actions.dart';
import 'chat_controller.dart';
import 'message_preview_text.dart';
import '../../storage/group_list_preview.dart';
import 'image_forward_dialog.dart';
import 'attachment_action_icon.dart';
import 'settings_appearance.dart';

class ImageForwardPage extends StatefulWidget {
  const ImageForwardPage({
    super.key,
    required this.controller,
    required ImageProvider image,
  }) : image = image,
       message = null,
       sendMessage = null;
  const ImageForwardPage.message({
    super.key,
    required this.controller,
    required AgentMessage message,
    this.sendMessage,
  }) : message = message,
       image = null;
  final ChatController controller;
  final ImageProvider? image;
  final AgentMessage? message;
  final Future<void> Function(String? targetId, String note)? sendMessage;
  @override
  State<ImageForwardPage> createState() => _ImageForwardPageState();
}

class _ImageForwardPageState extends State<ImageForwardPage> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final _items = <Conversation>[];
  final _senders = <String, MessageSender>{};
  final _groups = <String, List<MessageSender>>{};
  Timer? _debounce;
  int _generation = 0;
  bool _loading = false, _more = true, _sharing = false;
  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 240 && _more && !_loading) _load();
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
      if (reset) _items.clear();
    });
    try {
      final page = await widget.controller.imageForwardTargets(
        _search.text.trim(),
        _items.length,
      );
      final avatars = await Future.wait<Object?>([
        HomeConversations(widget.controller.groupStore).senders(page),
        widget.controller.groupStore.avatarMembers(
          page
              .where((c) => c.kind == ConversationKind.group)
              .map((c) => c.id)
              .toList(),
        ),
        loadConversationListPreviews(
          widget.controller.groupStore.database,
          page,
        ),
      ]);
      if (!mounted || generation != _generation) return;
      setState(() {
        if (reset) {
          _senders.clear();
          _groups.clear();
        }
        _senders.addAll(avatars[0] as Map<String, MessageSender>);
        _groups.addAll(avatars[1] as Map<String, List<MessageSender>>);
        _items.addAll(page);
        _more = page.length == 30;
      });
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showGlassSnackBar(
          SnackBar(content: Text('会话加载失败，请重新搜索：${errorMessage(error)}')),
        );
    } finally {
      if (mounted && generation == _generation)
        setState(() => _loading = false);
    }
  }

  Future<void> _select(Conversation item) async {
    FocusScope.of(context).unfocus();
    final sent = await showModalBottomSheet<bool>(
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
      builder: (_) => widget.message != null
          ? ImageForwardDialog.message(
              controller: widget.controller,
              message: widget.message!,
              sendMessage: widget.sendMessage,
              targetId: item.id,
              kind: item.kind,
              title: item.title,
              recipientName: item.kind == ConversationKind.group
                  ? '群聊'
                  : _senders[item.defaultSenderId]!.name,
              avatar: _avatar(item),
            )
          : ImageForwardDialog(
              controller: widget.controller,
              image: widget.image!,
              targetId: item.id,
              kind: item.kind,
              title: item.title,
              recipientName: item.kind == ConversationKind.group
                  ? '群聊'
                  : _senders[item.defaultSenderId]!.name,
              avatar: _avatar(item),
            ),
    );
    if (sent == true && mounted) Navigator.pop(context, true);
  }

  Future<void> _external() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      await PreviewImageActions.perform(widget.image!, 'share');
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showGlassSnackBar(
          SnackBar(content: Text('无法打开分享，请重试：${errorMessage(error)}')),
        );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: SettingsAppBar(
      title: widget.message == null ? '转发图片' : '转发消息',
      onBack: () => Navigator.pop(context),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: '搜索会话',
              filled: true,
              fillColor: settingsFieldColor(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) {
              _generation++;
              _debounce?.cancel();
              _debounce = Timer(
                const Duration(milliseconds: 250),
                () => _load(reset: true),
              );
            },
          ),
        ),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [
              if (widget.message == null)
                _row(
                  '其他应用',
                  const AttachmentActionIcon(
                    type: AttachmentActionIconType.forward,
                  ),
                  _sharing ? null : _external,
                ),
              for (final item in _items)
                _row(
                  item.title,
                  _avatar(item),
                  () => _select(item),
                  preview: item.preview,
                ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              if (!_loading && _items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('没有找到会话')),
                ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _avatar(Conversation item) {
    if (item.kind == ConversationKind.group) {
      return GroupAvatar(members: _groups[item.id]!, size: 48);
    }
    final sender = _senders[item.defaultSenderId]!;
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

  Widget _row(
    String title,
    Widget icon,
    VoidCallback? action, {
    String? preview,
  }) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      leading: SizedBox.square(dimension: 48, child: Center(child: icon)),
      horizontalTitleGap: 12,
      title: Text(
        title,
        style: const TextStyle(fontSize: 16),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: preview == null
          ? null
          : MessagePreviewText(
              text: preview,
              maxLines: 1,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
      onTap: action,
    ),
  );
}
