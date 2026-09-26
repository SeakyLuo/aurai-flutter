import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/ui_action.dart';
import '../../domain/message_sender.dart';
import '../../storage/group_announcement_store.dart';
import 'chat_controller.dart';
import 'group_announcement_page.dart';
import 'group_notice_card.dart';
import 'group_saved_message_preview.dart';
import '../../storage/group_message_marks.dart';
import '../../storage/group_message_search.dart';
import 'package:path_provider/path_provider.dart';
import 'markdown_preview_text.dart';
import 'message_time.dart';
import 'ai_contact_page.dart';
import 'personal_info_page.dart';
import 'app_dialog.dart';
import 'dialog_action_button.dart';

/// Reserves space below the chat header so the announcement cannot cover messages.
class GroupAnnouncementBanner extends StatefulWidget {
  const GroupAnnouncementBanner({
    super.key,
    required this.controller,
    required this.groupId,
    required this.builder,
    required this.onLocate,
  });
  final ChatController controller;
  final Future<void> Function(String) onLocate;
  final String? groupId;
  final Widget Function(BuildContext context, double announcementHeight)
  builder;

  @override
  State<GroupAnnouncementBanner> createState() =>
      _GroupAnnouncementBannerState();
}

class _GroupAnnouncementBannerState extends State<GroupAnnouncementBanner> {
  final _preferences = SharedPreferencesAsync();
  late final StreamSubscription<String> _subscription;
  GroupAnnouncement? _value;
  GroupMessageSearchResult? _pin;
  int? _pinStamp;
  late final StreamSubscription<String> _marks;
  int _loadId = 0;
  double _noticeHeight = 0;

  @override
  void initState() {
    super.initState();
    _subscription = GroupAnnouncementStore.changes.stream.listen((id) {
      if (id == widget.groupId) _load();
    });
    _marks = GroupMessageMarks.changes.stream.listen((id) {
      if (id == widget.groupId) _load();
    });
    _load();
  }

  @override
  void didUpdateWidget(GroupAnnouncementBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupId != widget.groupId) {
      _value = null;
      _pin = null;
      _load();
    }
  }

  Future<void> _load() async {
    final request = ++_loadId;
    final id = widget.groupId;
    if (id == null) return;
    await runUiAction(context, () async {
      final (value, dismissed, pinRow, pinDismissed) = await (
        GroupAnnouncementStore(
          widget.controller.groupStore,
        ).read(id, MessageSender.localUser.id),
        _preferences.getInt('groupAnnouncementDismissed:$id'),
        GroupMessageMarks(widget.controller.groupStore).pinned(id),
        _preferences.getInt('groupPinDismissed:$id'),
      ).wait;
      GroupMessageSearchResult? pin;
      if (pinRow != null && pinRow['updated_at'] != pinDismissed) {
        final root = await getApplicationSupportDirectory();
        final results = await GroupMessageSearch(
          widget.controller.groupStore.database,
          '${root.path}/message_images',
        ).hydrate([pinRow]);
        pin = results.single;
      }
      if (!mounted || request != _loadId) return;
      _pin = pin;
      _pinStamp = pinRow?['updated_at'] as int?;
      setState(
        () => _value = value?.updatedAt.microsecondsSinceEpoch == dismissed
            ? null
            : value,
      );
    });
  }

  Future<void> _dismiss() async {
    final id = widget.groupId!;
    final value = _value!;
    await runUiAction(context, () async {
      await _preferences.setInt(
        'groupAnnouncementDismissed:$id',
        value.updatedAt.microsecondsSinceEpoch,
      );
      if (mounted && widget.groupId == id && identical(_value, value)) {
        setState(() => _value = null);
      }
    });
  }

  Future<void> _open() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => GroupAnnouncementPage(
          controller: widget.controller,
          groupId: widget.groupId!,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openProfile(String senderId) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => senderId == MessageSender.localUser.id
            ? PersonalInfoPage(memory: widget.controller.memory)
            : AiContactPage(
                controller: widget.controller,
                senderId: senderId,
                groupId: widget.groupId,
              ),
      ),
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    _marks.cancel();
    super.dispose();
  }

  Future<void> _dismissPin() async {
    final id = widget.groupId!;
    final stamp = _pinStamp!;
    final messageId = _pin!.id;
    final action = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .24),
      builder: (context) => AppPromptDialog(
        title: '关闭置顶提示',
        description: '仅隐藏不影响其他成员；取消置顶对全群生效，原消息仍会保留。',
        actions: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DialogActionButton(
              text: '仅对我隐藏',
              onPressed: () => Navigator.pop(context, 'hide'),
            ),
            const SizedBox(height: 10),
            DialogActionButton(
              text: '为所有人取消置顶',
              role: DialogActionRole.destructive,
              onPressed: () => Navigator.pop(context, 'unpin'),
            ),
            const SizedBox(height: 10),
            DialogActionButton(
              text: '取消',
              role: DialogActionRole.secondary,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    await runUiAction(context, () async {
      if (action == 'unpin') {
        await GroupMessageMarks(
          widget.controller.groupStore,
        ).pin(id, messageId, false);
        return;
      }
      await _preferences.setInt('groupPinDismissed:$id', stamp);
      if (mounted && widget.groupId == id && _pinStamp == stamp) {
        setState(() => _pin = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final value = _value;
    final pin = _pin;
    final count = (value == null ? 0 : 1) + (pin == null ? 0 : 1);
    final height = count == 0 ? 0.0 : _noticeHeight;
    return Stack(
      children: [
        Positioned.fill(child: widget.builder(context, height)),
        if (count > 0)
          Positioned(
            top:
                View.of(context).padding.top /
                    View.of(context).devicePixelRatio +
                76,
            left: 0,
            right: 0,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: _NoticeSize(
                  onChanged: (size) {
                    if (mounted && _noticeHeight != size.height) {
                      setState(() => _noticeHeight = size.height);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        if (value != null) ...[
                          GroupNoticeCard(
                            author: value.editorName,
                            time: '${messageTime(value.updatedAt)} 更新',
                            preview: markdownPreviewText(value.content),
                            announcement: true,
                            onOpen: _open,
                            onDismiss: _dismiss,
                            onOpenProfile: () => _openProfile(value.editorId),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (pin != null) ...[
                          GroupNoticeCard(
                            author: pin.sender.name,
                            time: messageTime(pin.createdAt),
                            preview: groupSavedMessagePreview(pin),
                            announcement: false,
                            onOpen: () => widget.onLocate(pin.id),
                            onDismiss: _dismissPin,
                            onOpenProfile: () => _openProfile(pin.sender.id),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Reports the laid-out cards, including font metrics and accessibility scaling.
class _NoticeSize extends SingleChildRenderObjectWidget {
  const _NoticeSize({required this.onChanged, required super.child});
  final ValueChanged<Size> onChanged;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _NoticeSizeRenderObject(onChanged);

  @override
  void updateRenderObject(
    BuildContext context,
    _NoticeSizeRenderObject renderObject,
  ) {
    renderObject.onChanged = onChanged;
  }
}

class _NoticeSizeRenderObject extends RenderProxyBox {
  _NoticeSizeRenderObject(this.onChanged);
  ValueChanged<Size> onChanged;
  Size? _reported;

  @override
  void performLayout() {
    super.performLayout();
    if (_reported == size) return;
    _reported = size;
    final measured = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) onChanged(measured);
    });
  }
}
