import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../app/global_ui.dart';
import '../../domain/message_sender.dart';
import 'personal_info_page.dart';
import 'ai_contact_page.dart';
import '../../app/ui_action.dart';
import '../../storage/group_favorite_status.dart';
import '../../storage/group_message_marks.dart';
import 'image_action_scope.dart';

class GroupFavoriteMarker extends StatefulWidget {
  const GroupFavoriteMarker({
    super.key,
    required this.messageId,
    required this.isOwnMessage,
    required this.child,
  });
  final String messageId;
  final bool isOwnMessage;
  final Widget child;

  @override
  State<GroupFavoriteMarker> createState() => _GroupFavoriteMarkerState();
}

class _GroupFavoriteMarkerState extends State<GroupFavoriteMarker> {
  StreamSubscription<String>? _changes;
  GroupMarkRecord? _mark;
  final _profileTap = TapGestureRecognizer();
  int _revision = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_changes != null) return;
    _changes = GroupMessageMarks.changes.stream.listen((_) => _load());
    _load();
  }

  @override
  void didUpdateWidget(GroupFavoriteMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messageId != widget.messageId) {
      _mark = null;
      _load();
    }
  }

  Future<void> _load() async {
    final revision = ++_revision;
    await runUiAction(context, () async {
      final saved = await GroupFavoriteStatus.read(
        ImageActionScope.of(context).groupStore.database,
        widget.messageId,
      );
      if (mounted && revision == _revision) setState(() => _mark = saved);
    });
  }

  @override
  void dispose() {
    _changes?.cancel();
    _profileTap.dispose();
    super.dispose();
  }

  void _openProfile() {
    final mark = _mark!;
    final controller = ImageActionScope.of(context);
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => mark.actorId == MessageSender.localUser.id
            ? PersonalInfoPage(memory: controller.memory)
            : AiContactPage(
                controller: controller,
                senderId: mark.actorId!,
                groupId: mark.groupId,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mark = _mark;
    _profileTap.onTap = _openProfile;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: widget.isOwnMessage
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        widget.child,
        if (mark != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text.rich(
              TextSpan(
                children: [
                  if (mark.actorId != null && mark.actorName != null) ...[
                    TextSpan(
                      text: mark.actorName,
                      style: TextStyle(
                        color: GlobalUI.highlightTextColor(context),
                      ),
                      recognizer: _profileTap,
                    ),
                    const TextSpan(text: ' 标记了这条消息'),
                  ] else
                    const TextSpan(text: '已标记'),
                ],
              ),
              textAlign: widget.isOwnMessage ? TextAlign.end : TextAlign.start,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
